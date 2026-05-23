# Operations — token-bucket deep dive

> Detailed behavior, configuration, and tuning guidance for the
> server-side rate limiter. Complements
> [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
> with an operations perspective.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md`](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md).

## Schwab's official rate limit

Schwab does not publish exact per-account quotas. Community
measurements suggest **~120 req/min/user** for Market Data
Production. The official docs only say "rate limits apply, see
`Retry-After`", with no concrete number.

`schwab-marketdata-mcp` defaults `SCHWAB_RATE_LIMIT_PER_MIN=120` to
match the community measurement.

## Server implementation: token-bucket

```text
                    ┌─────────────────────┐
                    │ token-bucket        │
                    │ capacity = 120      │
  request ─────▶ acquire 1 slot ─┬──▶ schwab-py call
                    │             │
                    │             └──▶ slot expires after 60s
                    │                 (sliding window)
                    └─────────────────────┘
```

Specific behavior:

- **bucket capacity** = `SCHWAB_RATE_LIMIT_PER_MIN` (default 120)
- Each request consumes 1 slot; slots auto-recover after **60
  seconds** (**sliding window**, not a per-minute reset)
- When remaining slots < 20, the server emits a structured WARNING
  to stderr: `{"event":"rate_limit_warning","remaining":N}`
- When remaining slots == 0, the next call **raises immediately**
  with `SchwabRateLimitError`; it **does not block**

## Why not `asyncio.Semaphore`?

| Dimension                | `asyncio.Semaphore`                         | **token-bucket** (current choice) |
| ------------------------ | ------------------------------------------- | --------------------------------- |
| When no slot is available | `await acquire()` blocks                    | Raise immediately                  |
| During retry sleep        | Holds the slot, **blocks** other concurrent tools | **Releases** the slot for others |
| Concurrency profile      | Tools serialize                             | Tools parallel                    |
| MCP timeout risk         | Long awaits may exceed 30s timeout, breaking the protocol | Immediate raise; agent backs off itself |
| Throttling decision      | Made by the server (blocking)                | Made by the agent (retry cadence) |

**Key benefit**: a single slow tool (in retry-backoff) **does not
block** other concurrent tools (e.g. health_check or another quote
call).

## Configuration

`.env` fields:

```bash
# Local rate-limit cap; recommended 80-120
SCHWAB_RATE_LIMIT_PER_MIN=120

# Auto-retry attempts (429 / 5xx); default 2
SCHWAB_MAX_RETRIES=2

# Set to 0 in tests so failures surface immediately
# SCHWAB_MAX_RETRIES=0
```

## Tuning strategy

### Single agent, single server

```bash
SCHWAB_RATE_LIMIT_PER_MIN=100   # stricter than Schwab default; 20% headroom
```

Make local throttling fire before Schwab's, avoiding server-side
accounting (sustained quota busts trigger stricter server-side
throttling and even temporary suspension).

### Multiple agents / multiple Cursor windows pointing at one server

The token-bucket is shared at server-process scope. So multiple
agents adding up to ≤ 120 is fine:

```bash
SCHWAB_RATE_LIMIT_PER_MIN=120   # all agents share 120
```

### Multiple agents, each with its own server process

Each server process has its own bucket, but Schwab's account-level
quota is still shared. So:

```bash
# In each server's .env:
SCHWAB_RATE_LIMIT_PER_MIN=60   # two servers share 120
```

### High-frequency batch jobs

```bash
SCHWAB_RATE_LIMIT_PER_MIN=80   # leave more headroom for surprises
SCHWAB_MAX_RETRIES=3           # more retries, higher success rate
```

## Monitoring fields

Three rate-limit-related fields in `health_check()`:

| Field                              | Meaning                                           |
| ---------------------------------- | ------------------------------------------------- |
| `rate_limit_remaining_per_min`     | Current bucket remaining slots; < 20 deserves attention |
| `recent_error_count_24h`           | Cumulative `Schwab*Error` count over the past 24h (all types) |
| `last_request_status`              | Outcome of the most recent business call          |

## Failure-handling playbook

| Symptom                                | Recommendation                                              |
| -------------------------------------- | ----------------------------------------------------------- |
| `recent_error_count_24h` keeps rising   | Check whether `SCHWAB_RATE_LIMIT_PER_MIN` is set too high   |
| Multiple agents simultaneously hitting 0 slots | Halve `SCHWAB_RATE_LIMIT_PER_MIN`                          |
| `rate_limit_warning` appears every minute | Calling pattern is unhealthy; see [`../troubleshooting/rate-limit-warning-stderr.md`](../troubleshooting/rate-limit-warning-stderr.md) |

## What not to do

- **Do not** raise `SCHWAB_RATE_LIMIT_PER_MIN` above 120.
- **Do not** let the agent's own retry logic bypass the server's
  retry counter (stacked backoffs blow up exponentially).
- **Do not** spawn multiple server processes per agent to bypass
  the bucket — Schwab's account-level quota is still single-account
  shared.

## References

- Rate-limit troubleshooting: [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- 0 slots handling: [`../troubleshooting/rate-limit-token-bucket-empty.md`](../troubleshooting/rate-limit-token-bucket-empty.md)
- Architecture: [`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)
