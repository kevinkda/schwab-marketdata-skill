# Troubleshooting — `token_state` four-state explainer

> The `token_state` returned by `health_check()` is a **local file-state
> enum**, on a different axis from `SchwabAuthError(reason=...)`. This
> document covers the symptoms and remediation for each of the four
> states.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/auth-token-states.md`](../../../schwab-marketdata-ops/references/troubleshooting/auth-token-states.md).

## State table

| `token_state`      | Trigger condition                                              | Immediate action                                                  |
| ------------------ | -------------------------------------------------------------- | ----------------------------------------------------------------- |
| `valid`            | File exists + JSON valid + all fields present + permissions correct | Continue with normal traffic                                |
| `missing`          | `token.json` does not exist                                    | `auth login_flow`                                                 |
| `malformed`        | JSON corrupt / fields missing / schwab-py field incompatibility | Back up + delete + `auth login_flow`                             |
| `insecure_perms`   | File mode ≠ `600` or parent directory ≠ `700`                  | `chmod 600` token.json + `chmod 700` parent directory             |

## 1. `valid`

```bash
uv run python -m schwab_marketdata_mcp.health
# {"token_state":"valid","token_age_days":0.5,"token_expires_in_days":6.5,...}
```

`token_state == "valid"` **does not guarantee that the token will
succeed against the business API**. It only means the local file is
structurally correct. If a business call still returns
`SchwabAuthError`, the most common cause is the refresh_token having
been revoked server-side within the 7-day window (extremely rare,
usually triggered by a **Reset App Secret** cascade); you must re-run
OAuth.

## 2. `missing`

Most commonly seen when:

- The server has just been installed and `auth login_flow` has not
  been run yet
- You ran `rm token.json` and have not re-run OAuth
- The `--config-dir` you pointed at does not exist or contains no
  token.json

```bash
# Verify:
ls -la "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/"
# token.json should be present; if not, the state is missing.

# Fix:
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 3. `malformed`

Most commonly seen when:

- `token.json` was partially written (process killed mid-write, disk
  full)
- It was corrupted by an external tool (an editor, a sync tool)
- A schwab-py upgrade renamed fields and the old file is no longer
  compatible

```bash
# Verify:
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
cat "$TOKEN_PATH" | python -m json.tool
# JSONDecodeError = JSON corrupt
# KeyError = field missing (more likely a schwab-py version mismatch)

# Fix:
cp "$TOKEN_PATH" "${TOKEN_PATH}.bak.$(date +%s)"
rm "$TOKEN_PATH"
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 4. `insecure_perms`

Most commonly seen when:

- You used `cp -p` to copy the token from elsewhere and lost the mode
- Your `umask` is not `077`, so schwab-py wrote the file with the
  wrong permissions on first run
- `rsync` was run without `--perms`
- You restored the file on macOS from an NTFS / FAT32 external disk

```bash
# Verify:
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -c '%a %n' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"  # Linux
stat -f '%A %N' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"  # macOS
# Expected: 600 ...token.json   700 ...schwab-marketdata-mcp

# Fix:
chmod 700 "$(dirname "$TOKEN_PATH")"
chmod 600 "$TOKEN_PATH"

# Verify the fix:
uv run python -m schwab_marketdata_mcp.health   # exit 0
```

## State-transition diagram

```text
       initial
         │ install server
         ▼
    [missing] ──── auth login_flow ──── [valid] ──── (use for 7 days)
                                          │
                          token.json corrupted │
                                          ▼
                                    [malformed]
                                          │
                          back up + delete + login_flow
                                          ▼
                                       [valid]
                                          │
                          permissions changed / sync drops mode
                                          ▼
                                  [insecure_perms]
                                          │
                          chmod 600 / 700
                                          ▼
                                       [valid]
                                          │
                          7-day expiry
                                          ▼
                              SchwabAuthError(reason="refresh_token_expired")
                              (Note: token_state may still be "valid"
                               because the local file is unchanged, but
                               every business call will fail.)
```

Note the subtlety in step 4: **the 7-day expiry does not change
token_state**, because the local file is still well-formed; it only
manifests as `SchwabAuthError(reason="refresh_token_expired")` when
you actually call a business API. That's why the health module also
checks `token_expires_in_days < 12h` to surface a proactive warning.

## What not to do

- **Do not** treat `token_state == "valid"` as "all set". You also
  need to look at `token_expires_in_days` and `last_request_status`
  for the full picture.
- **Do not** rsync token.json across machines — rotate-on-use is
  fundamentally incompatible with cross-machine sharing.

## References

- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- 6 reasons in detail: [`auth-overview.md`](auth-overview.md) and the per-reason files
- Health-check automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
