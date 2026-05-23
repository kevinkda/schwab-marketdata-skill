# Troubleshooting — `SchwabAuthError(reason="refresh_token_expired_soon")`

A **warning-class** error: the refresh_token's 7-day absolute
lifetime has < 12 hours remaining. Strongly recommended to
reauthorize immediately rather than wait until it actually expires.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-refresh-expiring-soon.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-refresh-expiring-soon.md).

## Symptom

- `health_check()` returns `token_expires_in_days < 0.5`
- At server start, stderr shows
  `WARNING refresh_token_expires_soon`
- The cron `health.py` writes a marker file at
  `~/Desktop/SCHWAB_REAUTH_NEEDED.md`
- macOS Notification Center / Linux notify-send raises a
  notification

## Root cause

The refresh_token's **absolute** 7-day lifetime is almost up. This
is a hard limit of Schwab's OAuth and **cannot be bypassed**. No
client (schwab-py included) can extend it.

## Diagnostic command

```bash
uv run python -m schwab_marketdata_mcp.health
# Look at token_expires_in_days; < 0.5 = expires within 12 hours
```

## Fix commands

Standard laptop (recommended):

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
```

SSH-only / headless:

```bash
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## Verification

```bash
uv run python -m schwab_marketdata_mcp.health
# Expect: exit 0; token_state == "valid"; token_expires_in_days >= 6.5
ls ~/Desktop/SCHWAB_REAUTH_NEEDED.md 2>/dev/null && echo "marker still exists"
# Expect: the marker file has been deleted (the health module clears
# it once the token is valid)
```

## Why 12 hours instead of 1 hour?

Empirical observation: server-side refresh_token invalidation has a
~30-minute uncertainty window (caching plus clock drift); add the
desktop notification latency (cron 4h period + the time between the
user seeing the notification and actually sitting down to
reauthorize), and 12 hours is a reasonable buffer.

## What not to do

- **Do not** wait until the token is fully expired — every piece of
  in-flight agent work will then fail.
- **Do not** try to automate `auth login_flow` from cron — a human
  is required.

## References

- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- Fully expired handling: [`auth-refresh-expired.md`](auth-refresh-expired.md)
- Health-check automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
