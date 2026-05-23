# OAuth — `login_flow` (default)

> Recommended for **standard laptops** and any environment where a
> local https listener on port 8182 works.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-login-flow.md`](../../../schwab-marketdata-ops/references/oauth/oauth-login-flow.md).

## How it works

1. The CLI starts a local https listener on port `8182` with a
   **self-signed certificate**.
2. It opens the OS default browser to the Schwab login page.
3. You log in → click Allow → Schwab redirects to
   `https://127.0.0.1:8182/...`.
4. The browser shows `ERR_SSL_PROTOCOL_ERROR` / `Self-signed cert`
   one time: click **Advanced → Proceed** (this is the local
   certificate schwab-py auto-generates; it is the expected
   behavior).
5. The CLI receives the callback URL → posts to the Schwab token
   endpoint with the App Secret → exchanges for access_token +
   refresh_token → writes `token.json` (chmod 600).

## CLI

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## Required prerequisites

- `.env` contains `SCHWAB_CALLBACK_URL=https://127.0.0.1:8182`
  (byte-identical to the value registered on the Developer Portal)
- Port `8182` is **free**; check with `lsof -i :8182`
- The browser can reach `https://127.0.0.1:8182` (some corporate
  network proxies block loopback https)
- The system default browser is configured (macOS: Settings →
  Desktop & Dock → Default web browser; Linux:
  `xdg-settings get default-web-browser`)

## Verification

```bash
ls -l ~/.local/state/schwab-marketdata-mcp/token.json
# Expect: -rw------- ... token.json
uv run python -m schwab_marketdata_mcp.health
# Expect: exit 0, "token_state": "valid"
```

## When **not** to use `login_flow`

| Scenario                          | Use instead                                       |
| --------------------------------- | ------------------------------------------------- |
| SSH'd into a remote box           | [`oauth-manual-flow.md`](oauth-manual-flow.md)   |
| Inside a container (no GUI browser) | [`oauth-manual-flow.md`](oauth-manual-flow.md)   |
| WSL2 + browser on Windows         | `manual_flow` is simpler (avoids WSL2 port forwarding for 8182) |
| Corporate VPN blocks 127.0.0.1     | `manual_flow` or [`oauth-self-host-callback.md`](oauth-self-host-callback.md) |
| Port 8182 is occupied and cannot be released | Change `SCHWAB_CALLBACK_URL` in `.env` and the Portal registration in lockstep |

## Common errors (specific to `login_flow`)

| Symptom                                                       | Action                                                                              |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Browser shows `ERR_SSL_PROTOCOL_ERROR`                        | Click Advanced → Proceed; the self-signed cert is expected                          |
| Browser is stuck on `localhost refused to connect`            | Port is occupied (`lsof -i :8182`); or firewall is blocking loopback                |
| `MismatchingStateException ("CSRF Warning!")`                 | `.env` and Portal callback URL do not match; see [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md) |
| Browser never opens automatically                              | OS default browser is unset; manually open the URL printed to stdout                |
| After completion, `token.json` is missing                      | OAuth failed at the callback stage; check stderr for `Schwab*Error`                 |
| Port 8182 is occasionally seized by macOS Spotlight / Mail etc. | `stop <pid>` (or change port); remember to update the Portal value too              |

## What not to do

- **Do not** change `--port` and forget to update the Portal value
  — OAuth callback will inevitably fail with CSRF.
- **Do not** install the self-signed certificate into the system
  trust store (pointless; schwab-py regenerates it every time).
- **Do not** save the password for `127.0.0.1:8182` in the browser
  (pointless and confusing).

## References

- End-to-end OAuth: [`oauth-overview.md`](oauth-overview.md)
- `manual_flow` (headless alternative): [`oauth-manual-flow.md`](oauth-manual-flow.md)
- Callback URL mismatch troubleshooting: [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
