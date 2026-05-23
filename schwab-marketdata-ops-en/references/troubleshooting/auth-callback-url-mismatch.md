# Troubleshooting — `SchwabAuthError(reason="callback_url_mismatch")`

The `SCHWAB_CALLBACK_URL` in `.env` does not match the Callback URL
registered on the Schwab Developer Portal. OAuth performs a
**character-exact match** at the callback stage; a single
mismatched character causes failure.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-callback-url-mismatch.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-callback-url-mismatch.md).

## Symptom

- After `auth login_flow` opens the browser, the OAuth redirect step
  reports `MismatchingStateException ("CSRF Warning!")`
- The server raises this error directly at startup (startup-time
  validation)
- A business call will not trigger this reason — it surfaces during
  the very first OAuth attempt

## Root cause

The `.env` value of `SCHWAB_CALLBACK_URL` is **not exactly equal** to
the value registered on the [Developer Portal](https://developer.schwab.com/dashboard/apps).
A single-character difference (trailing slash, http vs https, port
number, subdomain, case) is enough to fail the match.

## Diagnostic command

```bash
grep -E '^SCHWAB_CALLBACK_URL=' /path/to/schwab-marketdata-mcp/.env
# Then check the registered value at https://developer.schwab.com/dashboard/apps
```

Or use dry-run to validate ahead of time:

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
# Outputs "Callback URL: ..."; character-diff against the Portal value.
```

## Fix command

Edit `.env` so that `SCHWAB_CALLBACK_URL` is **byte-identical** to the
value on the Developer Portal:

```bash
# Restart the server after editing .env
pkill -f schwab_marketdata_mcp || true
```

If you have already attempted OAuth a few times unsuccessfully:

```bash
# No need to rm token.json — since OAuth never succeeded, no token exists
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## Verification

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# Browser flow no longer reports the callback mismatch
uv run python -m schwab_marketdata_mcp.health   # exit 0
```

## 9 common mismatch patterns

For full detail see [`../oauth/oauth-callback-mismatch.md`](../oauth/oauth-callback-mismatch.md);
the 5 most common patterns are:

| In `.env`                            | On the Portal                          |
| ------------------------------------ | -------------------------------------- |
| `https://127.0.0.1:8182`             | `https://127.0.0.1:8182/`              |
| `http://127.0.0.1:8182`              | `https://127.0.0.1:8182`               |
| `https://localhost:8182`             | `https://127.0.0.1:8182`               |
| `https://127.0.0.1:8182/callback`    | `https://127.0.0.1:8182`               |
| Trailing hidden CR / LF              | (none)                                 |

## What not to do

- **Do not** try to register with a wildcard (Schwab does not support
  it).
- **Do not** quote the callback URL inside `.env` (the shell parsing
  changes the byte sequence).
- **Do not** retry OAuth repeatedly without diff'ing the `.env` value
  against the Portal — the OAuth code expires in 5 minutes, so
  repeated retries just waste time.

## References

- Callback URL mismatch deep dive: [`../oauth/oauth-callback-mismatch.md`](../oauth/oauth-callback-mismatch.md)
- OAuth login_flow: [`../oauth/oauth-login-flow.md`](../oauth/oauth-login-flow.md)
- OAuth manual_flow: [`../oauth/oauth-manual-flow.md`](../oauth/oauth-manual-flow.md)
