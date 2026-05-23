# Troubleshooting — `SchwabAuthError(reason="refresh_token_expired")`

**Already expired.** A human must run a full OAuth flow again.
**No** token roll / refresh attempt can recover from this.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-refresh-expired.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-refresh-expired.md).

## Symptom

- Business tool calls return
  `{"error":"SchwabAuthError","reason":"refresh_token_expired"}`
- schwab-py's internal refresh fails with `OAuth2Error: invalid_grant`
- `health_check()` may **still** report `token_state == "valid"` (the
  local file is unchanged), but every business call fails

## Root cause

The refresh_token's **absolute** 7-day lifetime has expired and the
server has invalidated it; **no recovery is possible**. This is a
hard limit of Schwab's OAuth.

## Diagnostic command

```bash
uv run python -m schwab_marketdata_mcp.health
# token_state == "valid" but token_expires_in_days <= 0
```

## Fix commands

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# Remote / SSH-only:
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## Verification

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# Then call get_quote("VOO") via a minimal MCP client and confirm 200 OK
# (see quick-start/step-5-first-mcp-tool-call.md)
```

## Common confusions

| Confusion                                   | The truth                                                  |
| ------------------------------------------- | ---------------------------------------------------------- |
| "I just refreshed, it shouldn't be expired" | A refresh does not extend the 7-day total lifetime; it only rotates a new RT |
| "Can I roll back to an old token.json backup?" | No. rotate-on-use invalidates the old RT immediately      |
| "Can the 7-day limit be bypassed?"           | No. This is built into Schwab's OAuth design, enforced server side |
| "Will restarting the server fix it?"         | No. Restarting the server has no effect on server-side token state |

## Agent behavior constraints

- The agent **must stop** and let the user run `auth login_flow`;
  **do not** silently retry.
- The agent should print the exact command to stdout / chat (`uv run
  python -m schwab_marketdata_mcp.auth login_flow`) so the user can
  copy-paste.
- The agent **should not** delete token.json proactively — schwab-py
  will overwrite it once the user reauthorizes.

## What not to do

- **Do not** run `login_flow` from cron (OAuth requires a human).
- **Do not** treat this as a transient error and retry.
- **Do not** confuse it with a callback URL mismatch (different
  reason).

## References

- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- Early-warning handling: [`auth-refresh-expiring-soon.md`](auth-refresh-expiring-soon.md)
- OAuth login_flow: [`../oauth/oauth-login-flow.md`](../oauth/oauth-login-flow.md)
- OAuth manual_flow: [`../oauth/oauth-manual-flow.md`](../oauth/oauth-manual-flow.md)
