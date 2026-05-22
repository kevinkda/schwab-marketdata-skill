# Quick Start — Step 4: Verify token is healthy

> **Goal**: Use the `schwab_marketdata_mcp.health` module to confirm the
> token is actually usable and to wire up cron / launchd health probes
> (Step 7 will deepen this).

## Prerequisites

- [ ] Step 3 completed and `token.json` is on disk

## Steps

### 1. One-shot health probe

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.health
```

Expected output (JSON, key fields):

```json
{
  "server_version": "0.1.x",
  "token_state": "valid",
  "token_age_days": 0.01,
  "token_expires_in_days": 6.99,
  "rate_limit_remaining_per_min": 120,
  "recent_error_count_24h": 0,
  "platform_supported": true
}
```

`token_state` must be `"valid"`; `token_expires_in_days` must be ≥ 6.5
(immediately after a fresh OAuth it should be 7.00 minus a small drift).

### 2. Interpreting `token_state`

| Value | Meaning | Fix |
| ----- | ------- | --- |
| `valid` | token.json present, JSON valid, all fields present, mode correct | ✅ Continue to Step 5 |
| `missing` | `token.json` does not exist | Re-run [Step 3](step-3-first-oauth.md) |
| `malformed` | JSON corrupt / fields missing | `mv token.json token.json.bak.$(date +%s)`, then re-run [Step 3](step-3-first-oauth.md) |
| `insecure_perms` | Mode is not `600` / parent dir is not `700` | `chmod 600 token.json && chmod 700 $(dirname token.json)` |

### 3. Practice the reauthorize drill

```bash
# Back up the current token (do not delete the original, just copy)
cp ~/.local/state/schwab-marketdata-mcp/token.json{,.drill.$(date +%s)}

# Run health (still expected to be valid since the original was not touched)
uv run python -m schwab_marketdata_mcp.health

# Or manually expire it:
echo '{}' > ~/.local/state/schwab-marketdata-mcp/token.json
uv run python -m schwab_marketdata_mcp.health
# Expected: token_state == "malformed"

# Restore the original token:
cp ~/.local/state/schwab-marketdata-mcp/token.json.drill.* ~/.local/state/schwab-marketdata-mcp/token.json
```

## Expected outcome

- `health` module exits 0
- stdout contains `"token_state": "valid"` and `token_expires_in_days >= 6.5`
- `~/Desktop/SCHWAB_REAUTH_NEEDED.md` does not exist (the health module
  only writes this file when the token is about to expire or is corrupt)

## Verification checklist

- [ ] `uv run python -m schwab_marketdata_mcp.health` exits 0
- [ ] stdout contains `"token_state": "valid"`
- [ ] `token_expires_in_days >= 6.5`
- [ ] `recent_error_count_24h == 0` (always 0 on first run)
- [ ] `platform_supported == true` (macOS 11+ / Linux)
- [ ] `~/Desktop/SCHWAB_REAUTH_NEEDED.md` does not exist

## Common failures

| Symptom | Fix |
| ------- | --- |
| `token_state == "valid"` but `token_expires_in_days` is `null` | schwab-py too old; `uv sync --upgrade-package schwab-py` |
| `token_state == "insecure_perms"` | `chmod 600 ~/.local/state/schwab-marketdata-mcp/token.json` and `chmod 700 ~/.local/state/schwab-marketdata-mcp` |
| `platform_supported == false` | macOS < 11 or Windows; server v0.1 only supports macOS 11+ / Linux |
| stdout shows `recent_error_count_24h > 0` even though you just authorized | A failure occurred in a previous session; check `~/.local/state/schwab-marketdata-mcp/logs/server.log` for the root cause |

## What not to do

- **Do not** paste the `health` stdout into issues / chat (it contains
  token metadata). First mask `App Key` and any `Bearer ...` traces.

## Next step

→ [Step 5: First MCP tool call](step-5-first-mcp-tool-call.md)

## References

- `health.py` internals: MCP repo `src/schwab_marketdata_mcp/health.py`
- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- 6 TokenState reasons: [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
