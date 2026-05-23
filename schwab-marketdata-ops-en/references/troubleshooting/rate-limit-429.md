# Troubleshooting — Schwab `429 Too Many Requests`

A server-side 429 — you have hit Schwab's ~120 req/min/user quota
wall. schwab-py has already retried `SCHWAB_MAX_RETRIES` (default 2)
times honoring the `Retry-After` header without success and is
returning the error to the agent.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-429.md`](../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-429.md).

## Symptom

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": 30,           // server-supplied wait time
  "current_window_used": 120,
  "message": "Rate limit reached"
}
```

## Root cause

You (or your agent) hit the ~120 req/min/user quota wall. schwab-py
already retried `SCHWAB_MAX_RETRIES` (default 2) times honoring the
`Retry-After` header without success.

## Diagnostic command

```bash
# Look at recent server-side throttle stats
echo '{"method":"health_check","params":{}}' | <your mcp client>
# Focus on rate_limit_remaining_per_min (slots left) and recent_error_count_24h
```

Or via stdio shell:

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"health_check","arguments":{}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson'
```

## Remediation strategy

### 1. Immediate (agent behavior)

```text
- Wait retry_after_seconds, then retry once
- Two consecutive failures → tell the user
- Agent applies exponential backoff: sleep 1s → 2s → 4s, then give up
```

### 2. Short term (task-shape changes)

| Anti-pattern                            | Replace with                               |
| --------------------------------------- | ------------------------------------------ |
| Looping `get_quote(SYM)` × N           | `get_quotes(symbols=[...])`, up to 50 per call |
| Looping `get_price_history` per day for daily candles | Coarser period (`MONTH`/`YEAR`) in one call |
| Repeatedly calling `get_market_hours`   | Agent-side memory cache, TTL 30s            |

### 3. Long term (config changes)

```bash
# Lower the local rate limit in .env so the local limit fires before Schwab's:
SCHWAB_RATE_LIMIT_PER_MIN=80
```

Make the local limit the first wall to avoid being recorded
server-side (sustained quota busts trigger stricter server-side
throttling and even temporary account suspension).

## Verification

```bash
# Successful retries + recent_error_count_24h in health_check stops growing
uv run python -m schwab_marketdata_mcp.health
```

## Multi-agent concurrency notes

The token-bucket is shared at **server-process** scope. If you run
two Cursor windows talking to the same server, **both** count
against the per-minute quota. Recommendations:

- One server process per (machine, account) pair
- For multi-agent setups, split the budget in `.env` (e.g.
  `SCHWAB_RATE_LIMIT_PER_MIN=60`) so the sum of agents stays ≤ 120

## What not to do

- **Do not** retry the same call ≥ 3 times immediately (triggers
  stricter throttling).
- **Do not** assume `Retry-After` is always present; see
  [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md).
- **Do not** push `SCHWAB_RATE_LIMIT_PER_MIN` above 120 (Schwab
  will fire its own limit first).

## References

- Rate-limit overview: [`rate-limit-overview.md`](rate-limit-overview.md)
- token-bucket deep dive: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 0 slots immediate raise: [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)
