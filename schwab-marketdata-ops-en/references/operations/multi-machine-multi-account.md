# Operations — Multi-machine & multi-account

> Design constraints you need to know when running
> schwab-marketdata-mcp on ≥ 2 machines or ≥ 2 Schwab accounts.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/operations/multi-machine-multi-account.md`](../../../schwab-marketdata-ops/references/operations/multi-machine-multi-account.md).

## TL;DR

- **Multi-machine, single account**: each machine runs OAuth
  **independently**; **do not** copy token.json.
- **Single machine, multi-account**: use `--config-dir` to point at
  a different token directory; each account has its own `.env` and
  its own OAuth.
- **Multi-machine + multi-account**: combine the two; run OAuth once
  for each (machine, account) Cartesian product.

## Why can't I copy token.json across machines?

The `refresh_token` is **rotate-on-use**: every refresh issues a
new one and invalidates the old one. So:

```text
Machine A: access_token AT₁ + refresh_token RT₁
        ↓ auto-refresh after 80 minutes
       AT₂ + RT₂ (RT₁ invalidated immediately)

Machine B (after copying token.json):
       still holds AT₁ + RT₁ → tries to refresh → invalid_grant → all calls fail
```

Empirically, Schwab also performs behavioral analysis on the same
refresh_token used from different IPs; sustained cross-IP use can
**temporarily lock the account**.

## Correct procedure for multi-machine, single account

### First machine

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth login_flow
# Writes to the default ~/.local/state/schwab-marketdata-mcp/token.json
```

### Second machine

Run OAuth again, **logging in with the same Schwab account**:

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
```

⚠️ Once the second machine completes OAuth, **does the first
machine's refresh_token expire?**

**Not necessarily**. Schwab's token endpoint is **idempotent on
issuance**: each new OAuth issues an independent refresh_token, and
they do not invalidate each other. The two machines can each hold
distinct RTs side by side. But:

- When **either** machine refreshes, **only that machine's** RT
  rotates; the other is unaffected.
- When **both** machines call APIs concurrently, Schwab counts
  against the account-level quota (120 req/min shared).

## Single machine, multi-account

Each account gets its own token directory and `.env` file:

### Directory layout

```text
~/.local/state/
├── schwab-marketdata-mcp/             # default account A
│   └── token.json
├── schwab-marketdata-mcp-account-b/   # account B
│   └── token.json
└── schwab-marketdata-mcp-account-c/   # account C
    └── token.json
```

### One OAuth per account

```bash
# Account A (default directory)
uv run python -m schwab_marketdata_mcp.auth login_flow

# Account B
uv run python -m schwab_marketdata_mcp.auth login_flow \
    --config-dir ~/.local/state/schwab-marketdata-mcp-account-b

# Account C
uv run python -m schwab_marketdata_mcp.auth login_flow \
    --config-dir ~/.local/state/schwab-marketdata-mcp-account-c
```

`--config-dir` must land in the allow-list subdirectory
(`~/.local/state` or `~/.config`; see
[`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)).

### How do I structure `.env`?

Each account is **a different Developer Portal app** → different
App Key / Secret / Callback URL. Recommended: use **a separate
schwab-marketdata-mcp checkout per account**:

```text
~/code/kevinkda/schwab-marketdata-mcp-A/    # checkout 1, .env A
~/code/kevinkda/schwab-marketdata-mcp-B/    # checkout 2, .env B
```

Then register two entries in `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "schwab-marketdata-A": {
      "command": "/abs/path/to/uv",
      "args": ["--directory", "/home/you/code/kevinkda/schwab-marketdata-mcp-A", "run", "schwab-marketdata-mcp"]
    },
    "schwab-marketdata-B": {
      "command": "/abs/path/to/uv",
      "args": ["--directory", "/home/you/code/kevinkda/schwab-marketdata-mcp-B", "run", "schwab-marketdata-mcp"]
    }
  }
}
```

## Health-check cron

Run health independently per account:

```cron
# Account A
0 */4 * * * cd /home/you/code/kevinkda/schwab-marketdata-mcp-A && /abs/uv run python -m schwab_marketdata_mcp.health

# Account B
30 */4 * * * cd /home/you/code/kevinkda/schwab-marketdata-mcp-B && /abs/uv run python -m schwab_marketdata_mcp.health
```

## What not to do

- **Do not** `rsync` token.json across machines — rotate-on-use is
  incompatible.
- **Do not** share a single `.env` across multiple accounts — App
  Key / Secret are different.
- **Do not** store multiple accounts' tokens in the default
  directory — separate them via `--config-dir`.
- **Do not** assume Schwab's account-level quota is split by IP —
  it is split by account-key (per Developer Portal app).

## References

- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- Token path allow-list: [`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)
- Credential leak response: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
