# Troubleshooting — `SchwabAuthError(reason="token_corrupted")`

The token.json file exists but cannot be parsed or is missing fields.
Back it up, delete it, and re-run OAuth.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-token-corrupted.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-token-corrupted.md).

## Symptom

- `health_check()` returns `token_state == "malformed"`
- At server start, stderr reports `JSONDecodeError` or a missing
  critical field (e.g. `access_token`, `refresh_token`,
  `creation_timestamp`)
- A business call returns `{"error":"SchwabAuthError","reason":"token_corrupted"}`

## Root cause (4 typical patterns)

1. token.json was partially written (process crashed mid-write, disk
   full, filesystem fault)
2. It was modified by an external tool (editor mis-edit, sync tool
   pre-empted the write, backup script truncated it)
3. A schwab-py version upgrade renamed fields or changed the
   structure, and the old file is no longer compatible
4. It was truncated mid-rsync (rsync uses chunked writes by default;
   a network blip leaves a partial file)

## Diagnostic commands

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"

# 1) Is the JSON well-formed?
cat "$TOKEN_PATH" | python -m json.tool
# An error here confirms JSON corruption.

# 2) Are the critical fields present?
python3 -c "
import json, sys
data = json.loads(open('$TOKEN_PATH').read())
required = {'creation_timestamp', 'token'}
missing = required - data.keys()
if missing:
    print('missing top-level keys:', missing)
inner_required = {'access_token', 'refresh_token'}
inner_missing = inner_required - data.get('token', {}).keys()
if inner_missing:
    print('missing token-level keys:', inner_missing)
"
```

## Fix commands

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"

# 1) Back up first (do not rm directly — keep yourself a rollback point)
cp "$TOKEN_PATH" "${TOKEN_PATH}.bak.$(date +%s)"

# 2) Delete the original
rm "$TOKEN_PATH"

# 3) Re-run OAuth
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## Verification

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# Expect: token_state == "valid"
```

## How long should backups be kept?

At most 7 days (the refresh_token lifetime). Past 7 days a rollback
is meaningless (the old refresh_token has been invalidated server
side). Recommended: clean up weekly:

```bash
find "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/" \
    -name 'token.json.bak.*' -mtime +7 -delete
```

## What not to do

- **Do not** `rm` without backing up first — if the new OAuth fails,
  you've lost any chance to inspect the corrupted fields for
  diagnosis.
- **Do not** try to hand-edit token.json to repair fields — the
  refresh_token is server-issued, you cannot fix it locally.

## References

- Four TokenStates: [`auth-token-states.md`](auth-token-states.md)
- Credential rotation runbook: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
