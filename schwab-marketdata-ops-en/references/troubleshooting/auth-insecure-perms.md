# Troubleshooting — `SchwabAuthError(reason="insecure_token_perms")`

token.json's mode is not `600`, or the parent directory is not `700`,
so the server refuses to start.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-insecure-perms.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-insecure-perms.md).

## Symptom

- At server start, stderr shows `chmod 600 ...` / `chmod 700 ...`
  hints
- `health_check()` returns `token_state == "insecure_perms"`
- A business call returns
  `{"error":"SchwabAuthError","reason":"insecure_token_perms"}`

## Root cause (5 typical patterns)

1. `umask` is not `077`; schwab-py wrote the file with the wrong
   mode the first time
2. You used `cp -p` from elsewhere and the **destination** mode was
   the default (`644`)
3. `rsync` was run without `--perms`
4. You restored the token from an NTFS / FAT32 external disk on
   macOS (FAT32 does not support unix permissions)
5. Another process (IDE / file manager) running as administrator
   rewrote the file

## Diagnostic commands

### Linux

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -c '%a %n' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"
# Expected:
#   600 ~/.local/state/schwab-marketdata-mcp/token.json
#   700 ~/.local/state/schwab-marketdata-mcp
```

### macOS

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -f '%A %N' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"
```

## Fix commands

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
chmod 700 "$(dirname "$TOKEN_PATH")"
chmod 600 "$TOKEN_PATH"
```

## Verification

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# Expect: token_state == "valid"
```

## Prevent recurrence

Add `umask 077` to your shell rc:

```bash
# ~/.zshrc or ~/.bashrc
umask 077
```

Or set it temporarily in the shell that runs the server:

```bash
umask 077 && uv run schwab-marketdata-mcp
```

## Why is the server this strict?

token.json contains the refresh_token; if it leaks an attacker can
**call any Market Data API on your behalf** for 7 days, plus (if
they refresh in time) keep rotating it. The standard minimum
permission on Linux / macOS is `600` (owner read/write only); there
is no reason to relax it.

## What not to do

- **Do not** try `chmod 644` or `chmod 666` to bypass the check —
  the server re-validates at startup.
- **Do not** add a `--no-perm-check` flag to the server CLI (no such
  flag exists; this is by design).

## References

- Four TokenStates: [`auth-token-states.md`](auth-token-states.md)
- Credential leak response: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- OAuth flow: [`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
