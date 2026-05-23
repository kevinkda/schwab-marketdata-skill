# Troubleshooting — Rate limit overview

> Quick triage for the 4 rate-limit-related symptoms. For the
> complete token-bucket behavior reference, see
> [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md).

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-overview.md`](../../../schwab-marketdata-ops/references/troubleshooting/rate-limit-overview.md).

## Routing table

| Symptom                                                       | Child file                                                            |
| ------------------------------------------------------------- | --------------------------------------------------------------------- |
| Schwab returns `429 Too Many Requests`                         | [`rate-limit-429.md`](rate-limit-429.md)                              |
| token-bucket 0 slots, raised immediately (`retry_after_seconds == 0`) | [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md) |
| stderr emits `rate_limit_warning` (remaining < 20) but the call still succeeded | [`rate-limit-warning-stderr.md`](rate-limit-warning-stderr.md)        |
| 429 but the response is missing the `Retry-After` header (rare) | [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)        |

## Error shape

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": <int>,        // 0 = local token-bucket empty; >0 = Schwab server side
  "current_window_used": <int>,        // slots used in the current minute window
  "message": "Rate limit reached"
}
```

## Decision flow

1. **Look at `retry_after_seconds`**:
   - `> 0` → Schwab server-side 429; wait that many seconds and
     retry once.
   - `== 0` or missing → local token-bucket has 0 slots; the agent
     should apply exponential backoff.
2. **Two consecutive retries fail** → tell the user, lower
   concurrency / call frequency.
3. **Field `retry_after_seconds` completely absent** → extremely
   rare, see
   [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md).

## General throttle-relief strategies

| Scenario                                   | Remediation                                     |
| ------------------------------------------ | ----------------------------------------------- |
| Repeated single-shot `get_quote(SYM)` × N  | Switch to a single `get_quotes(symbols=[...])` |
| `get_price_history` in a loop pulling daily candles | Use a coarser period (`MONTH`/`YEAR`) once       |
| High-frequency metadata calls (e.g. `get_market_hours`) | Cache in memory on the agent side, TTL 30s     |
| Multi-agent concurrency                    | Lower `SCHWAB_RATE_LIMIT_PER_MIN`              |
| Long batch jobs                            | Split the playbook so each chunk does ≤ 30 tool calls |

## What not to do

- **Do not** retry the same call ≥ 3 times immediately on
  `SchwabRateLimitError` (it triggers stricter server-side throttling).
- **Do not** raise `SCHWAB_RATE_LIMIT_PER_MIN` above 120 (the
  Schwab server-side limit will fire first anyway).
- **Do not** assume independence in multi-agent concurrency — the
  token-bucket is shared at server-process level.

## References

- token-bucket deep dive: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Error model overview: [`../error-recovery.md`](../error-recovery.md)
- Authorization errors: [`auth-overview.md`](auth-overview.md)
