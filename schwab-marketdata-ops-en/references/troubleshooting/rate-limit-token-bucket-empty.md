# Troubleshooting — token-bucket 0 slots (instantaneous burst)

The business tool **immediately** raises `SchwabRateLimitError` with
`retry_after_seconds == 0` (or the field missing). This is the
expected behavior when the local rate limit fires before Schwab's;
it is up to the agent to choose the backoff cadence.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-token-bucket-empty.md`](../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-token-bucket-empty.md).

## Symptom

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": 0,          // note: 0, not a large number
  "current_window_used": 120,
  "message": "Local token-bucket exhausted"
}
```

And:

- stderr has emitted (or is about to emit)
  `{"event":"rate_limit_warning","remaining":<20}`
- The call never reached Schwab (no server-side quota was consumed)
- No `Retry-After` HTTP header trace (because the server never made
  the upstream call)

## Root cause

The local token-bucket capacity is exhausted (≥ 120 requests have
already been issued in the current minute window). The server
**does not block**; instead it raises immediately, leaving the
throttling decision to the agent. This is a deliberate design
choice in the `Semaphore` vs `token-bucket` selection, intended to
avoid retry-sleep blocking other tools.

See [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md).

## Diagnostic command

```bash
# Watch stderr live during the call
tail -f ~/.local/state/schwab-marketdata-mcp/logs/server.log
# Expect to see, beforehand:
#   {"event":"rate_limit_warning","remaining":15}
#   {"event":"rate_limit_warning","remaining":3}
```

Or via health:

```bash
uv run python -m schwab_marketdata_mcp.health \
  | jq '.rate_limit_remaining_per_min'
# Close to 0 = bucket exhausted
```

## Remediation strategy (agent side)

### Exponential backoff retry

```python
import asyncio

async def call_with_backoff(call, max_attempts=3):
    for attempt in range(max_attempts):
        result = await call()
        err = result.get("error")
        if err != "SchwabRateLimitError":
            return result
        wait = 2 ** attempt   # 1s, 2s, 4s
        await asyncio.sleep(wait)
    raise RuntimeError("rate limit exhausted after backoff")
```

### TypeScript equivalent

```typescript
async function callWithBackoff<T>(
    call: () => Promise<{ error?: string } & T>,
    maxAttempts = 3,
): Promise<T> {
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        const result = await call();
        if (result.error !== "SchwabRateLimitError") return result;
        await new Promise((r) => setTimeout(r, 2 ** attempt * 1000));
    }
    throw new Error("rate limit exhausted after backoff");
}
```

### Lower concurrency on the next batch

```python
# Wrong: 60 symbols dispatched in parallel
results = await asyncio.gather(*[get_quote(s) for s in symbols])

# Right: use the batch tool (one slot for ≤ 50 symbols)
result = await get_quotes(symbols=symbols[:50])
```

## Why doesn't the server sleep on its own?

If the server used `asyncio.Semaphore` and awaited until a slot
freed up, you'd get:

1. **Blocking**: the caller thinks the call is still running, but
   it's actually queued waiting for a slot.
2. **Protocol timeout**: MCP clients default to 30s timeout; long
   sleeps cause the client to disconnect.
3. **Concurrency damage**: the slot is held during retry sleep, so
   other concurrent tools must queue.

token-bucket + immediate raise hands cadence control to the agent —
a much better contract.

## Verification

```bash
# Three consecutive retries no longer raise immediately
for i in 1 2 3; do
    sleep 5
    # Call a lightweight tool
    ...
done
```

## What not to do

- **Do not** set retry intervals below 1s (no point — the bucket
  needs at least 60s to refill).
- **Do not** start multiple server processes to bypass the limit
  (the token-bucket is per server process, but the sum still hits
  Schwab's limit).
- **Do not** modify the server source to remove rate limiting (you
  will get throttled even harder server-side).

## References

- Rate-limit overview: [`rate-limit-overview.md`](rate-limit-overview.md)
- token-bucket deep dive: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Server-side 429: [`rate-limit-429.md`](rate-limit-429.md)
