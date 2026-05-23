# Troubleshooting — overview

> Routing table: jump to the matching child file based on the `error`
> field value you see.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-overview.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-overview.md).

## Routing — by `error` type

| `error` field value         | Child file                                                          | Meaning                                         |
| --------------------------- | ------------------------------------------------------------------- | ----------------------------------------------- |
| `SchwabAuthError`           | [`auth-overview.md`](auth-overview.md)                              | OAuth / token / credential failures (6 reasons) |
| `SchwabRateLimitError`      | [`rate-limit-overview.md`](rate-limit-overview.md)                  | Rate-limit failures (429, token-bucket empty, missing Retry-After) |
| `SchwabValidationError`     | [`validation-overview.md`](validation-overview.md)                  | Pydantic input validation rejection             |
| `SchwabTransientError`      | [`transient-errors.md`](transient-errors.md)                        | Schwab 5xx / network jitter                     |

## Routing — by symptom

| Symptom                                               | Jump to                                                                    |
| ----------------------------------------------------- | -------------------------------------------------------------------------- |
| `health_check` returns `token_state != "valid"`       | [`auth-token-states.md`](auth-token-states.md)                            |
| `SchwabAuthError(reason="refresh_token_expired_soon")` | [`auth-refresh-expiring-soon.md`](auth-refresh-expiring-soon.md)        |
| `SchwabAuthError(reason="refresh_token_expired")`     | [`auth-refresh-expired.md`](auth-refresh-expired.md)                      |
| `SchwabAuthError(reason="token_not_initialized")`     | [`auth-token-not-initialized.md`](auth-token-not-initialized.md)         |
| `SchwabAuthError(reason="token_corrupted")`           | [`auth-token-corrupted.md`](auth-token-corrupted.md)                      |
| `SchwabAuthError(reason="insecure_token_perms")`      | [`auth-insecure-perms.md`](auth-insecure-perms.md)                        |
| `SchwabAuthError(reason="callback_url_mismatch")`     | [`auth-callback-url-mismatch.md`](auth-callback-url-mismatch.md)         |
| Schwab returns 429                                    | [`rate-limit-429.md`](rate-limit-429.md)                                  |
| Token-bucket 0 slots, raised immediately              | [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)   |
| stderr `rate_limit_warning` but call succeeded        | [`rate-limit-warning-stderr.md`](rate-limit-warning-stderr.md)            |
| 429 but no `Retry-After` header                       | [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)            |
| Symbol regex mismatch                                 | [`validation-symbol.md`](validation-symbol.md)                            |
| price-history Cartesian product is illegal            | [`validation-pricehistory-cartesian.md`](validation-pricehistory-cartesian.md) |
| `get_quotes` exceeds 50                               | [`validation-batch-50.md`](validation-batch-50.md)                        |
| OSI format wrong                                      | [`validation-osi-format.md`](validation-osi-format.md)                    |
| Schwab 5xx                                            | [`transient-errors.md`](transient-errors.md)                              |

## Decision flow

1. **Always check the `error` field first** before presenting results to
   the user. If non-empty, jump to the matching child file via the
   table above; **do not** show a raw stack trace to the user.
2. For `SchwabAuthError(reason ∈ {refresh_token_expired,
   token_not_initialized, callback_url_mismatch})` — **the agent must
   stop and ask the user to run `auth login_flow`**; do not silently
   retry.
3. For `SchwabRateLimitError` — you may retry once after
   `retry_after_seconds`; two consecutive failures → tell the user.
4. For `SchwabValidationError` — the agent should **fix the input and
   retry once** (e.g. `aapl` → `AAPL`, split 60 symbols into 50 + 10);
   only escalate to the user if it still fails after the fix.
5. For `SchwabTransientError` — wait a few minutes and retry; if you
   see ≥ 3 of the same error within 30 minutes, tell the user Schwab
   may be having an outage.

## What not to do

- **Do not** echo any `Bearer ...` header to user-visible output.
  The MCP server applies a global redaction filter, but the agent
  should add a final masking pass as defense-in-depth.
- **Do not** silently retry on `SchwabAuthError`.
- **Do not** use `git push --force` to scrub credential leaks from
  history; follow the safe branch + PR review flow in
  [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md).

## References

- Error model overview: [`../error-recovery.md`](../error-recovery.md)
- Credential rotation runbook: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- Health-check automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
