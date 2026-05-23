# Troubleshooting — `SchwabRateLimitError` (legacy redirect)

> This file is preserved for backward compatibility with old
> references; the content has been reorganized into the
> [`troubleshooting/`](troubleshooting/) subdirectory.

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/troubleshooting-rate-limit.md`](../../schwab-marketdata-ops/references/troubleshooting-rate-limit.md).

## New locations

Split per symptom into individual files:

| Symptom                              | Child file                                                                          |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| Schwab server-side 429               | [`troubleshooting/rate-limit-429.md`](troubleshooting/rate-limit-429.md)            |
| Local token-bucket 0 slots           | [`troubleshooting/rate-limit-token-bucket-empty.md`](troubleshooting/rate-limit-token-bucket-empty.md) |
| `rate_limit_warning` (call still succeeded) | [`troubleshooting/rate-limit-warning-stderr.md`](troubleshooting/rate-limit-warning-stderr.md) |
| 429 missing `Retry-After` header (rare) | [`troubleshooting/rate-limit-no-retry-after.md`](troubleshooting/rate-limit-no-retry-after.md) |

## Entry point

Main entry (routing table + decision flow):
[`troubleshooting/rate-limit-overview.md`](troubleshooting/rate-limit-overview.md)

token-bucket implementation deep dive (for tuning):
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md)
