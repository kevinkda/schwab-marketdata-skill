# Rate limits & paging

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/rate-limits-and-paging.md`](../../schwab-marketdata-ops/references/rate-limits-and-paging.md).

## Schwab's official limits

Schwab does not publish exact per-account quotas. Community
measurement suggests **~120 req/min/user** for Market Data
Production. The `schwab-marketdata-mcp` server defaults to that
value via `SCHWAB_RATE_LIMIT_PER_MIN=120`.

## How the server enforces it

A **token-bucket** with sliding-window expiry sits in front of every
schwab-py call:

- Bucket capacity = `SCHWAB_RATE_LIMIT_PER_MIN` (default 120).
- Each request consumes 1 slot; the slot auto-recovers `60 s`
  later.
- When fewer than `20` slots remain, a structured `WARNING` line is
  written to stderr (`{"event":"rate_limit_warning","remaining":N}`).
- When `0` slots remain, the next call **immediately** raises
  `SchwabRateLimitError` instead of blocking; the agent decides how
  to pace itself.

> **Why not `asyncio.Semaphore`?** A Semaphore would keep its slot
> across an automatic retry sleep, blocking unrelated tools. The
> token-bucket releases the slot during retry sleep so other
> concurrent tools can keep going.

## Paging

The current 10 endpoints **do not** support cursor-based paging.
When you need many quotes:

1. Split the symbol list into ≤50-symbol batches yourself. The
   server will **reject** a 51-symbol `get_quotes` with
   `SchwabValidationError(field="symbols")`.
2. Stagger calls by ~0.5 s if you are near the per-minute budget;
   or set `SCHWAB_RATE_LIMIT_PER_MIN` lower to make the local
   limiter pre-empt before Schwab does.

For historical price history, use
`period_type="DAY"/"MONTH"/"YEAR"` to adjust the granularity rather
than asking for many ranges.

## Retry-After honoring

When Schwab returns `429 Too Many Requests`, the server:

1. Reads the `Retry-After` header (seconds).
2. Sleeps that long **without** holding a bucket slot.
3. Retries up to `SCHWAB_MAX_RETRIES` times (default 2).

After the retry budget is exhausted, the call is reported as
`SchwabRateLimitError(retry_after_seconds=…, current_window_used=…)`
to the agent.

## Disabling retries (for tests)

```bash
SCHWAB_MAX_RETRIES=0 uv run pytest …
```

The integration tests use this so a flaky scenario fails fast
instead of consuming the test runner's wall time.

## Troubleshooting

Quick remediation for the 3 common symptoms (full version in
`troubleshooting-rate-limit.md`):

### 1. `rate_limit_warning` (remaining < 20)

stderr emits `{"event":"rate_limit_warning","remaining":<20}` while
the business call still succeeds.

- **Recommendation**: replace multiple single-shot `get_quote` calls
  with a single `get_quotes` (up to 50 symbols = 1 slot).
- **Recommendation**: reduce in-loop frequency of
  `get_price_history`; use a coarser `period_type` to fetch in one
  go.
- **Recommendation**: when orchestrating playbooks, cache
  high-frequency metadata calls (`get_market_hours`,
  `get_server_info`) in memory (30s TTL).

### 2. 0 slots (instantaneous burst against 120/min)

The business tool **immediately** raises `SchwabRateLimitError`
with `retry_after_seconds` missing or zero.

- **Server-side cause**: local token-bucket capacity is exhausted;
  the server does not block but raises immediately, handing
  throttle decision-making to the agent (so other concurrent tools
  are not blocked).
- **Agent-side handling**: apply exponential backoff (1s / 2s /
  4s); if 3 consecutive retries still raise → tell the user and
  reduce concurrency.

### 3. `Retry-After` header missing

Schwab returns 429 but the response has no `Retry-After` header
(rare).

- **Server-side fallback**: schwab-py internally falls back to
  **exponential backoff** (1s / 2s) by default; the agent typically
  does not observe this.
- **Agent-side handling**: if `SCHWAB_MAX_RETRIES` is exhausted and
  it still fails → treat as ordinary `SchwabRateLimitError`; wait
  30–60s and retry.
