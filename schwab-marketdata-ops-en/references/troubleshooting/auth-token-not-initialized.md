# Troubleshooting — `SchwabAuthError(reason="token_not_initialized")`

The state immediately after a **fresh install** or after you ran
`rm token.json`. The fix is the simplest possible: run `auth
login_flow` once.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-token-not-initialized.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-token-not-initialized.md).

## Symptom

- You call any tool immediately after the first server start
- `health_check()` returns `token_state == "missing"`
- A business call returns `{"error":"SchwabAuthError","reason":"token_not_initialized"}`

## Root cause

There is no `token.json` under the default token path; OAuth has
never been completed via `login_flow`.

## Diagnostic command

```bash
ls -la "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/"
# Expect to see token.json; if missing, the token has not been initialized.
```

## Fix command

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# or:
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## Verification

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
ls -l "$TOKEN_PATH"
# Expect to see -rw------- (chmod 600)

uv run python -m schwab_marketdata_mcp.health   # exit 0
# Expect: token_state == "valid"
```

## Difference vs. `token_corrupted`

| Dimension             | `token_not_initialized` | `token_corrupted`                            |
| --------------------- | ----------------------- | -------------------------------------------- |
| File present?         | No                      | Yes                                          |
| `token_state`         | `missing`               | `malformed`                                  |
| When it triggers      | First install / after `rm` | JSON corrupt / fields missing / schwab-py upgrade |
| Fix                   | `auth login_flow`       | Back up + delete + `auth login_flow`         |

## What not to do

- **Do not** silently fall back to a dummy token at server start —
  raise immediately so the user knows OAuth is required.
- **Do not** copy someone else's token.json over (rotate-on-use +
  single-machine binding).

## References

- Four TokenStates: [`auth-token-states.md`](auth-token-states.md)
- First-time OAuth: [`../quick-start/step-3-first-oauth.md`](../quick-start/step-3-first-oauth.md)
- Full OAuth: [`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
