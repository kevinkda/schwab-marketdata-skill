# OAuth — Callback URL mismatch deep dive

> Lists 9 common callback-URL mismatch patterns and the byte-level
> fixes.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-callback-mismatch.md`](../../../schwab-marketdata-ops/references/oauth/oauth-callback-mismatch.md).

`SCHWAB_CALLBACK_URL` must be **byte-identical** to the Callback URL
registered on the Developer Portal (a single-character difference
counts as a mismatch).

## 9 common mismatch patterns

| # | In `.env`                            | Registered on the Portal              | Fix                                    |
| - | ------------------------------------ | ------------------------------------- | -------------------------------------- |
| 1 | `https://127.0.0.1:8182`             | `https://127.0.0.1:8182/`             | Append `/` to `.env`                    |
| 2 | `https://127.0.0.1:8182/`            | `https://127.0.0.1:8182`              | Strip trailing `/` from `.env`          |
| 3 | `http://127.0.0.1:8182`              | `https://127.0.0.1:8182`              | Change `http` to `https` (Schwab rejects http) |
| 4 | `https://127.0.0.1`                  | `https://127.0.0.1:8182`              | Add `:8182` in `.env`, or remove `:8182` from the Portal |
| 5 | `https://localhost:8182`             | `https://127.0.0.1:8182`              | Change `localhost` to `127.0.0.1`       |
| 6 | `https://127.0.0.1:8182/callback`    | `https://127.0.0.1:8182`              | Drop the `/callback` path               |
| 7 | `https://127.0.0.1:8182?foo=bar`     | `https://127.0.0.1:8182`              | Drop the query string                   |
| 8 | Uppercase or mixed-case host         | All-lowercase host                    | Lowercase everything                    |
| 9 | URL has invisible trailing chars (CR) | None                                  | `cat -A .env` to detect; fix with `sed -i 's/\r$//' .env` |

## Pre-validate with `--dry-run`

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
# Expected output:
#   Callback URL: https://127.0.0.1:8182
# Diff this byte-for-byte against the value at
# https://developer.schwab.com/dashboard/apps
```

Or via shell:

```bash
ENV_VAL="$(grep -E '^SCHWAB_CALLBACK_URL=' .env | cut -d= -f2-)"
PORTAL_VAL='https://127.0.0.1:8182'  # paste manually from the Portal
diff <(printf '%s' "$ENV_VAL") <(printf '%s' "$PORTAL_VAL")
# No output = byte-identical
```

## Specific errors during the OAuth callback stage

| Error                                              | Meaning                                                       |
| -------------------------------------------------- | ------------------------------------------------------------- |
| `MismatchingStateException ("CSRF Warning!")`      | The redirect_uri schwab-py received differs from the one it sent → almost always `.env` vs Portal mismatch |
| `OAuth2Error: invalid_grant`                       | Code already exchanged or > 5 minutes old; re-run `auth login_flow` |
| `OAuth2Error: invalid_client`                      | App Key or App Secret wrong; check the three fields in `.env` |
| `redirect_uri_mismatch`                            | Returned by Schwab; same root cause as `MismatchingStateException` above |

## Verification after the fix

```bash
# 1) After editing .env, dry-run to see the new value
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run

# 2) Re-run OAuth
uv run python -m schwab_marketdata_mcp.auth login_flow

# 3) Verify the token actually works
uv run python -m schwab_marketdata_mcp.health
```

## What not to do

- **Do not** try to register wildcards / multiple callback URLs in
  the Portal (Schwab does not support wildcards, only **exact
  string match**; multi-callback support is enterprise-only and not
  available for individual apps).
- **Do not** quote the callback URL inside `.env` (the shell
  modifies bytes after parsing); schwab-py reads the literal value.

## References

- End-to-end OAuth: [`oauth-overview.md`](oauth-overview.md)
- `login_flow`: [`oauth-login-flow.md`](oauth-login-flow.md)
- `manual_flow`: [`oauth-manual-flow.md`](oauth-manual-flow.md)
- General auth-error handling: [`../troubleshooting/auth-callback-url-mismatch.md`](../troubleshooting/auth-callback-url-mismatch.md)
