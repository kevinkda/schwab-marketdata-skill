# Troubleshooting — `rate_limit_warning` in stderr

stderr emits the structured warning
`{"event":"rate_limit_warning","remaining":<20}`, but the business
call **still succeeds**. This is a warning, not an error.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-warning-stderr.md`](../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-warning-stderr.md).

## Symptom

```text
2025-05-23 10:42:18,123 WARNING {"event":"rate_limit_warning","remaining":15}
2025-05-23 10:42:18,455 WARNING {"event":"rate_limit_warning","remaining":7}
```

The business call does not return an `error` field; the reply
payload is normal.

## Root cause

The remaining slot count for the current minute has dropped below
20. The server emits this as a proactive warning to alert the agent
(or operator) of impending exhaustion. A high-frequency call within
the same minute window may then trigger
[`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md).

## Diagnostic commands

```bash
tail -n 100 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep rate_limit_warning
```

Or check current remaining:

```bash
uv run python -m schwab_marketdata_mcp.health \
    | jq '.rate_limit_remaining_per_min'
```

## Remediation strategy

### 1. Replace single-shot calls with batches

```python
# Anti-pattern
for sym in symbols:
    await get_quote(sym)               # 1 slot per call

# Correct
await get_quotes(symbols=symbols[:50])  # 1 slot for 50 symbols
```

### 2. Reduce in-loop frequency of `get_price_history`

```python
# Anti-pattern: pull 5 days of daily candles in a loop
for day in last_5_days:
    await get_price_history(period_type="DAY", period="ONE_DAY", ...)

# Correct: pull 6 months of daily candles in one call, slice agent-side
history = await get_price_history(
    period_type="MONTH", period="SIX_MONTHS",
    frequency_type="DAILY",
)
last_5 = [c for c in history["candles"] if recent(c["datetime"])]
```

### 3. Cache high-frequency metadata calls in memory

```python
# Anti-pattern: get_market_hours on every call
async def is_market_open():
    h = await get_market_hours(markets_list=["EQUITY"])
    return h["equity"]["EQ"]["isOpen"]

# Correct: process-level cache, 30s TTL
_cache = {}
async def is_market_open():
    now = time.time()
    if "v" in _cache and now - _cache["t"] < 30:
        return _cache["v"]
    h = await get_market_hours(markets_list=["EQUITY"])
    v = h["equity"]["EQ"]["isOpen"]
    _cache.update(t=now, v=v)
    return v
```

## Verification

After several minutes, observe that the warning no longer appears
and `recent_error_count_24h` is flat.

```bash
sleep 300   # Wait 5 minutes
tail -n 200 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep -c rate_limit_warning   # Should be low
```

## Design rationale for the threshold of 20

20 ≈ 16% × 120, leaving the agent **roughly 10s** of reaction time
(at ~120 req/min) to choose its backoff. Setting it higher would
warn too often; lower would leave no buffer window.

## What not to do

- **Do not** treat `rate_limit_warning` as a business error (the
  call still succeeded).
- **Do not** surface it in user-visible chat (it should silently
  drive the agent to slow down).

## References

- 0 slots true error: [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)
- token-bucket implementation: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Caching strategy: [`../operations/observability-and-caching.md`](../operations/observability-and-caching.md)
