# Error recovery — index

The MCP server normalizes every Schwab failure into a structured
dict (with a non-None `error` field) and **does not let exceptions
propagate** through the MCP protocol. This file is only a **routing
index**; specific handling lives in the three troubleshooting child
files.

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/error-recovery.md`](../../schwab-marketdata-ops/references/error-recovery.md).

---

## Routing — by `error` type

| `error` | Child file | Meaning |
| ------- | ---------- | ------- |
| `SchwabAuthError` | [`troubleshooting-auth.md`](troubleshooting-auth.md) | OAuth / token / credential failures (6 reasons) |
| `SchwabRateLimitError` | [`troubleshooting-rate-limit.md`](troubleshooting-rate-limit.md) | Rate-limit failures (429, token-bucket 0 slots, missing Retry-After) |
| `SchwabValidationError` | [`troubleshooting-validation.md`](troubleshooting-validation.md) | Pydantic input validation rejection (symbol regex, Cartesian product, >50 symbols, OSI format) |
| `SchwabTransientError` | (this file, §1) | Schwab 5xx / network jitter; server has already retried `SCHWAB_MAX_RETRIES` times |

---

## §1. `SchwabTransientError` (handled in this file)

- **Symptom**: `{"error":"SchwabTransientError","status_code":<5xx or non-401/429 4xx>,"message":…}`.
- **Root cause**:
  - 5xx: Schwab server-side fault / gateway timeout; schwab-py
    already retried `SCHWAB_MAX_RETRIES` (default 2) times with
    exponential backoff and still failed.
  - 4xx other than 401/429: usually edge-case input not caught by
    Pydantic (e.g. a field where Schwab is stricter than the docs).
- **Remediation strategy**:
  - 5xx: wait a few minutes, then retry; if you see ≥ 3 occurrences
    in 30 minutes → tell the user Schwab may be having an outage;
    suggest the [Schwab Developer Portal Status](https://developer.schwab.com/)
    page.
  - 4xx: cross-check parameters against
    `troubleshooting-validation.md` and `tool-reference.md`; if
    still stuck → file an issue in the schwab-marketdata-mcp repo.
- **Verification**: ≥ 1 success out of 3 retries = transient
  jitter; sustained failure = real outage.

---

## Decision flow for the agent

1. **Always check the `error` field first** before presenting
   results to the user. If non-empty, route to the matching child
   file via the table above; **do not show a raw stack trace to the
   user**.
2. For `SchwabAuthError(reason ∈ {refresh_token_expired,
   token_not_initialized, callback_url_mismatch})` — **the agent
   must stop and ask the user to run `auth login_flow`**; do not
   silently retry.
3. For `SchwabRateLimitError` — you may retry once after
   `retry_after_seconds`; two consecutive failures → tell the user.
4. For `SchwabValidationError` — the agent should **fix the input
   and retry once** (`aapl` → `AAPL`, split 60 symbols into 50 +
   10); only escalate to the user if it still fails after the fix.

---

## What not to do

- **Do not** echo any `Bearer …` header to user-visible output.
  The MCP server applies a global redaction filter, but the agent
  should add a final masking pass as defense-in-depth.
- **Do not** silently retry on `SchwabAuthError`.
- **Do not** use `git push --force` to scrub credential leaks from
  history; follow the safe branch + PR review flow in
  [`credentials-rotate-runbook.md`](credentials-rotate-runbook.md).
