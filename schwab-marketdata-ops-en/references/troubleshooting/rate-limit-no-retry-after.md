# Troubleshooting — 429 missing `Retry-After` header

Schwab returns `429 Too Many Requests` but the response has no
`Retry-After` HTTP header. **Rare**, but needs a fallback.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-no-retry-after.md`](../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-no-retry-after.md).

## Symptom

server.log shows:

```text
2025-05-23 10:42:18,123 WARNING schwab returned 429 with no Retry-After header
2025-05-23 10:42:19,400 INFO    falling back to exponential backoff: sleep 1s
2025-05-23 10:42:20,800 INFO    retry attempt 2, sleeping 2s
```

The eventual business call may succeed or fail:

- Success: transparent; the agent does not observe anything
- Failure: returns `SchwabRateLimitError(retry_after_seconds=<schwab-py default>)`

## Root cause

An upstream edge node / WAF rewrote the headers, or a network
middlebox stripped them. The Schwab server should send
`Retry-After` per RFC 7231, but in practice it occasionally drops.

## Server-side fallback

schwab-py internally falls back to **exponential backoff** (1s / 2s
/ 4s) by default, so the agent typically does not observe this.
Only after `SCHWAB_MAX_RETRIES` (default 2) attempts have failed is
the error surfaced.

## Diagnostic command

```bash
# Check the server log to confirm schwab-py was retrying
grep -E "(429|Retry-After|retry attempt)" \
    ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | tail -50
```

## Remediation strategy

No agent intervention is required; if `SCHWAB_MAX_RETRIES` is
exhausted and the call still fails, treat it as an ordinary
`SchwabRateLimitError` (see
[`rate-limit-429.md`](rate-limit-429.md)).

## Verification

```bash
# After 5 minutes, recent_error_count_24h should stop growing
uv run python -m schwab_marketdata_mcp.health
```

## What not to do

- **Do not** layer your own agent-side exponential backoff on top of
  the server's fallback — duplicated backoff makes the wait
  unnecessarily long.
- **Do not** raise `SCHWAB_MAX_RETRIES` to a large number (e.g.
  10) — exponential backoff blows up; waiting several minutes is
  worse than telling the user immediately.

## References

- Standard 429: [`rate-limit-429.md`](rate-limit-429.md)
- token-bucket implementation: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Rate-limit overview: [`rate-limit-overview.md`](rate-limit-overview.md)
