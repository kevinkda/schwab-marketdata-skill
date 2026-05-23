# Operations — Observability & caching

> Observability and caching strategy on both server and agent
> sides; avoid anti-pattern calls that waste quota.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/operations/observability-and-caching.md`](../../../schwab-marketdata-ops/references/operations/observability-and-caching.md).

## Server-side observable signals

### 1. server.log (structured)

Default path: `${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/logs/server.log`

Format: `RotatingFileHandler` 10 MB × 5 rotated. One structured
log line per record:

```text
2025-05-23 10:42:18,123 INFO  initialize received from clientInfo=...
2025-05-23 10:42:18,234 INFO  call_tool name=get_quote args={"symbol":"AAPL"}
2025-05-23 10:42:18,455 INFO  schwab_response status=200 elapsed_ms=210
2025-05-23 10:43:01,001 WARNING {"event":"rate_limit_warning","remaining":15}
2025-05-23 10:44:15,200 ERROR  schwab_response status=429 retry_after=30
```

### 2. health_check (real-time snapshot)

```bash
uv run python -m schwab_marketdata_mcp.health
```

Returned fields (see [`../tools/tool-reference-meta.md`](../tools/tool-reference-meta.md)):

- `token_state` — local token state
- `token_age_days` / `token_expires_in_days`
- `rate_limit_remaining_per_min`
- `recent_error_count_24h`
- `last_request_status`

### 3. Structured stderr warning

`{"event":"rate_limit_warning","remaining":N}` — fires when bucket
remaining < 20.

## Agent-side caching strategy (strongly recommended)

Not every call needs to hit the server fresh. The table below
suggests **process-level** caching on the agent side:

| Tool                          | Recommended TTL | Cache key                                    |
| ----------------------------- | --------------- | -------------------------------------------- |
| `get_server_info`             | Process lifetime | — (once per startup)                          |
| `get_market_hours`            | 30s              | (markets_list, date)                          |
| `get_market_hour_single`      | 30s              | (market_id, date)                            |
| `get_option_expiration_chain` | 60s              | symbol                                       |
| `health_check`                | **No cache**     | — (you want the live state)                   |
| `get_quote` / `get_quotes`    | **No cache**     | — (caching live quotes is meaningless)        |
| `get_price_history`           | 60s              | (symbol, period_type, period, frequency_type, frequency, start, end) |
| `get_movers`                  | 30s              | (index, sort_order, frequency)                |
| `search_instruments`          | 5 min            | (symbols, projection)                         |
| `get_instrument_by_cusip`     | 1 day            | cusip (fundamental metadata is stable)        |

### Minimal Python implementation

```python
import asyncio
import time

class TimedCache:
    def __init__(self, ttl_seconds: float):
        self.ttl = ttl_seconds
        self._store: dict[tuple, tuple[float, object]] = {}

    async def get_or_fetch(self, key: tuple, fetch):
        now = time.time()
        if key in self._store:
            t, v = self._store[key]
            if now - t < self.ttl:
                return v
        v = await fetch()
        self._store[key] = (now, v)
        return v


market_hours_cache = TimedCache(30)

async def cached_market_hours(client, markets_list):
    return await market_hours_cache.get_or_fetch(
        tuple(markets_list),
        lambda: client.call("get_market_hours", {"markets_list": list(markets_list)}),
    )
```

## Anti-patterns and rewrites

| Anti-pattern                                              | Rewrite                                                            | Saved               |
| --------------------------------------------------------- | ------------------------------------------------------------------ | ------------------- |
| Looping `get_quote(s)` over 50 symbols                    | Single `get_quotes(symbols=[...])`                                  | 50 slots → 1 slot    |
| `get_market_hours` every minute to test if market is open  | 30s TTL cache                                                      | 60 slots → 2 slots   |
| Looping `get_price_history(period_type="DAY", ...)` per day | Single `get_price_history(period_type="MONTH", "SIX_MONTHS")` and slice | N slots → 1 slot     |
| Repeatedly calling `get_server_info` to probe version     | Call once at skill activation, cache for the process               | M slots → 1 slot     |
| Caching real-time quotes for 60s                          | **Do not cache**                                                   | — (caching quote is a bug) |

## Monitoring & alerting suggestions

### cron health check (see Quick Start Step 7)

```cron
0 */4 * * * /path/to/uv run python -m schwab_marketdata_mcp.health \
    | jq -e '.token_state == "valid" and .recent_error_count_24h < 50' \
    || /path/to/notify.sh "Schwab MCP unhealthy"
```

### Simple local dashboard

```bash
# Pipe health output through jq to track trends
while true; do
    date
    uv run python -m schwab_marketdata_mcp.health \
        | jq -c '{token_state, expires: .token_expires_in_days, slots: .rate_limit_remaining_per_min, errs_24h: .recent_error_count_24h}'
    sleep 30
done
```

## What not to do

- **Do not** cache `health_check` — what you want is the live
  state.
- **Do not** cache `get_quote` / `get_quotes` — caching real-time
  quotes is meaningless.
- **Do not** persist the cache to disk — process-level in-memory
  is sufficient; cross-process persistence is more likely to be
  stale.
- **Do not** ship server.log INFO-level lines to a third-party log
  service (they contain call metadata that can leak your strategy).

## References

- token-bucket deep dive: [`rate-limit-token-bucket.md`](rate-limit-token-bucket.md)
- meta tool reference: [`../tools/tool-reference-meta.md`](../tools/tool-reference-meta.md)
- Health-check automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
