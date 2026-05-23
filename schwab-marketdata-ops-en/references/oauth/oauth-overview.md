# OAuth flow overview

End-to-end Schwab 3-legged OAuth walkthrough plus a `login_flow`
vs. `manual_flow` decision tree.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-overview.md`](../../../schwab-marketdata-ops/references/oauth/oauth-overview.md).

> Schwab Market Data Production uses **3-legged OAuth 2.0**, with
> `schwab-py` handling the token exchange. This document gives the
> end-to-end flow diagram and a mode decision tree; the child files
> drill into each mode in detail.

## Flow diagram

```text
┌──────────────┐  1. open browser/print URL  ┌───────────────────┐
│  You (human) │ ──────────────────────────▶ │ Schwab OAuth UI   │
│              │                              │ (login + Allow)   │
│              │  2. redirect ?code=...       │                   │
│              │ ◀──────────────────────────  │                   │
└──────────────┘                              └───────────────────┘
       │                                              │
       │ 3. CLI receives code                         │
       ▼                                              │
┌──────────────────────┐  4. token exchange (POST)    │
│ schwab-py CLI        │ ──────────────────────────▶ Schwab token endpoint
│ (login_flow /        │                              │
│  manual_flow)        │  5. {access_token,           │
│                      │      refresh_token, ...}    │
│                      │ ◀──────────────────────────  │
│ 6. write             │
│    token.json        │
│    chmod 600         │
└──────────────────────┘
```

## Mode decision tree

| Scenario                                              | Recommended mode      | Detailed doc                                              |
| ----------------------------------------------------- | --------------------- | --------------------------------------------------------- |
| Standard laptop + can listen on local https :8182      | `login_flow` (default) | [`oauth-login-flow.md`](oauth-login-flow.md)             |
| SSH-only / Docker / WSL2 / browser cannot reach 127.0.0.1 | `manual_flow`         | [`oauth-manual-flow.md`](oauth-manual-flow.md)           |
| Want to be fully independent of schwab-py's callback listener | self-host callback     | [`oauth-self-host-callback.md`](oauth-self-host-callback.md) |
| Cron / unattended automation                           | **Not supported**     | Schwab OAuth requires a human at least once               |
| Multi-account / multi-machine                          | One OAuth per account / per machine | Do not copy `token.json` (refresh_token is machine-bound + rotate-on-use) |

## Common CLI entry point for the three modes

```bash
# Default: login_flow
uv run python -m schwab_marketdata_mcp.auth login_flow

# Headless / remote
uv run python -m schwab_marketdata_mcp.auth manual_flow

# Custom token path (must land in the allow-list subdirectory)
uv run python -m schwab_marketdata_mcp.auth login_flow --config-dir ~/.config/schwab

# Override cloud-sync safety (only when you understand the consequences)
uv run python -m schwab_marketdata_mcp.auth login_flow --i-understand-cloud-sync-risk

# Dry-run (does not open the browser; just prints the callback URL — useful for debugging)
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
```

## Three token components

| Component        | Lifetime            | Auto-refresh?                                                |
| ---------------- | ------------------- | ------------------------------------------------------------ |
| `access_token`   | 90 minutes          | Yes — schwab-py checks before every API call and refreshes it transparently |
| `refresh_token`  | **7-day absolute lifetime** | No — after 7 days you must re-run OAuth (cannot be bypassed; this is by design) |
| OAuth `code`     | One-time use, 5 minutes | No — invalidated as soon as the OAuth flow completes         |

**rotate-on-use**: every refresh issues a **new refresh_token** that
replaces the old one. This means:

1. You **cannot** copy `token.json` to another machine and use them
   simultaneously (whichever refresh hits first invalidates the
   other).
2. After backing up `token.json`, you **cannot** roll back to that
   backup (the refresh_token has been rotated).
3. Multi-machine same-account requires running OAuth multiple times.

See [`oauth-token-lifecycle.md`](oauth-token-lifecycle.md) for the
full lifecycle.

## Token persistence path

Default: `${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/token.json`
(identical on Linux and macOS — we deliberately avoid macOS's
`~/Library/Application Support` to keep cross-machine migration and
backup scripts uniform).

Permissions:

- `token.json`: `chmod 600`
- Parent directory: `chmod 700`

If permissions drift, the server refuses to start and prints a
`chmod 600 ...` hint.

## Verify the token actually works

```bash
# Recommended: built-in health module
uv run python -m schwab_marketdata_mcp.health
# Expect: exit 0; stdout contains "token_state": "valid"
```

Or use a minimal MCP client (see [Quick Start Step 5](../quick-start/step-5-first-mcp-tool-call.md))
to make one `get_quote("VOO")` call.

## What not to do

- **Do not** run `auth login_flow` directly from cron — OAuth
  requires human interaction.
- **Do not** copy `token.json` into a cloud sync drive (iCloud /
  Dropbox / OneDrive).
- **Do not** echo a `Bearer ...` header into any user-visible
  output (mask it first even if it appears in error messages).
- **Do not** wait until the 7-day window has lapsed — `health` warns
  proactively when < 12h remain.

## References

- `login_flow` deep dive: [`oauth-login-flow.md`](oauth-login-flow.md)
- `manual_flow` deep dive: [`oauth-manual-flow.md`](oauth-manual-flow.md)
- Self-hosted callback: [`oauth-self-host-callback.md`](oauth-self-host-callback.md)
- Token lifecycle: [`oauth-token-lifecycle.md`](oauth-token-lifecycle.md)
- Callback URL mismatch troubleshooting: [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
- TokenState 4-state explainer: [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
