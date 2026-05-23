# OAuth — `manual_flow` (headless / SSH-only)

> Recommended for SSH-attached remote machines, containers, WSL2,
> or any environment where the browser cannot reach `127.0.0.1`.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-manual-flow.md`](../../../schwab-marketdata-ops/references/oauth/oauth-manual-flow.md).

## How it works

1. The CLI **prints an OAuth authorize URL to stdout** (looking like
   `https://api.schwabapi.com/v1/oauth/authorize?...`).
2. You **copy** the URL and paste it into any browser that can reach
   Schwab (your laptop, phone, host machine), then log in → Allow.
3. Schwab redirects you to `https://127.0.0.1/?code=...&state=...`.
   The browser will show `Connection refused` or `Site can't be
   reached` — **this is expected** (nothing is listening on
   `127.0.0.1`).
4. From the browser **address bar**, copy the full redirect URL
   (including the entire `?code=...&state=...` query) and paste it
   back into the CLI's stdin.
5. The CLI parses the `code` → calls the token endpoint → writes
   `token.json`.

## CLI

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## Required prerequisites

- `.env` contains `SCHWAB_CALLBACK_URL=https://127.0.0.1` (**no
  port**; byte-identical to the value registered on the Developer
  Portal)
- Any browser that can reach <https://api.schwabapi.com> (does not
  need to be on the same machine; a phone is fine)
- The SSH session will not time out while `manual_flow` waits for
  input (recommended: run it inside tmux / screen so a network blip
  does not lose progress)

## Full conversation example

```bash
$ uv run python -m schwab_marketdata_mcp.auth manual_flow
[INFO] Manual OAuth flow.

Visit this URL in any browser, authorize the app, and paste the
redirect URL (the one your browser cannot load) below:

  https://api.schwabapi.com/v1/oauth/authorize?response_type=code&client_id=...&redirect_uri=https%3A%2F%2F127.0.0.1&state=...

Paste redirect URL: ▎
```

Copy the URL printed to stdout → log in via another browser → click
Allow → the browser jumps to
`https://127.0.0.1/?code=ABC...&session=…&state=...` (showing the
error page).

Copy the full address bar → paste back into the CLI's stdin →
press Enter.

```bash
Paste redirect URL: https://127.0.0.1/?code=ABC...&state=...
[INFO] Token persisted to /home/you/.local/state/schwab-marketdata-mcp/token.json
[INFO] Permissions chmod 600 enforced.
```

## Verification

```bash
ls -l ~/.local/state/schwab-marketdata-mcp/token.json
# Expect: -rw------- ... token.json
uv run python -m schwab_marketdata_mcp.health
# Expect: exit 0, "token_state": "valid"
```

## When **not** to use `manual_flow`

| Scenario                          | Use instead                                     |
| --------------------------------- | ----------------------------------------------- |
| Standard laptop, can open 8182 locally | [`oauth-login-flow.md`](oauth-login-flow.md)   |
| Want to fully automate (no human)  | **Impossible** — by Schwab OAuth design          |

## Common errors (specific to `manual_flow`)

| Symptom                                                | Action                                                              |
| ------------------------------------------------------ | ------------------------------------------------------------------- |
| Browser jumps to `127.0.0.1` and shows `Connection refused` | **Expected behavior**; copy the full URL from the address bar       |
| Lost the `&state=...` part during copy/paste            | You must copy the full address; missing fields cause CSRF failure   |
| Extra space / newline during paste                      | Most shells preserve them; trim manually if necessary               |
| `MismatchingStateException`                            | Callback URL mismatch with the Portal; see [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md) |
| Code not exchanged within 5 minutes                     | OAuth code is one-time + short-lived; complete the paste step quickly |
| SSH session disconnected mid-flow                        | Reconnect and re-run `manual_flow` from scratch (the OAuth code is invalidated) |

## SSH long-session protection tip

```bash
# On the remote box:
tmux new -s schwab-oauth
uv run python -m schwab_marketdata_mcp.auth manual_flow
# If your local SSH disconnects, after reconnecting:
tmux attach -t schwab-oauth   # rejoin and continue
```

## What not to do

- **Do not** paste the OAuth URL printed to stdout into a public
  chat / issue — it contains `client_id` and `state` (harmless for
  the 5-minute window but a bad habit).
- **Do not** close the browser tab before exchanging `code=...` —
  the OAuth code is one-time; closing the tab forces you to re-run
  `manual_flow`.

## References

- End-to-end OAuth: [`oauth-overview.md`](oauth-overview.md)
- `login_flow` (default): [`oauth-login-flow.md`](oauth-login-flow.md)
- Self-hosted callback: [`oauth-self-host-callback.md`](oauth-self-host-callback.md)
- Callback URL mismatch troubleshooting: [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
