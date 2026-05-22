# Credentials rotation runbook

> **Trigger** — any of:
>
> - `gitleaks` / `detect-secrets` flagged a real-looking secret in a commit.
> - You realise `.env` was accidentally pushed to a public location.
> - Schwab Developer Portal flags suspicious activity.
> - A teammate or laptop loss raises any doubt.

This runbook prioritises the **legally meaningful action first** — i.e.
rotating the secret on Schwab's side, which is what actually severs
attacker access.  Repository hygiene comes second.

## ⚠️ Git Safety Protocol — non-negotiable rules

- **NEVER** force-push to `main` / `master` / `mainline` of a public or
  shared repository.
- **NEVER** rewrite history that has been pushed without first creating
  a security branch and going through normal PR review (even on a
  personal project — it preserves an audit trail).
- **NEVER** skip pre-commit hooks (`--no-verify`).
- **NEVER** trust GitHub's "remove" button to scrub a leaked commit;
  GitHub keeps dangling commit SHAs accessible for **months**.

These rules are inherited from the user's `.cursor/rules` plus the
system-wide Git Safety Protocol.

---

## Step-by-step

### 1. Rotate the Schwab secret (most important)

1. Open <https://developer.schwab.com/dashboard/apps>.
2. Locate the affected app.
3. Click **Reset App Secret**.  This invalidates the old secret
   immediately at Schwab's side, regardless of whether you have
   cleaned up the repo.

> Until this step is done, repository cleanup is **cosmetic**.  Do this
> step **first**.

### 2. Delete local token state

```bash
rm -f ~/.local/state/schwab-marketdata-mcp/token.json \
      ~/.local/state/schwab-marketdata-mcp/token.json.lock
```

(Adjust path if you used `--config-dir`.)

### 3. Audit git history

```bash
cd /path/to/the/repo
git log --all --full-history -- ".env*"
git log --all --full-history -- "**/token.json"
gitleaks detect --source . --log-opts="--all"
```

If nothing turns up, jump to step 6.

### 4a. If the secret was committed but **not yet pushed to remote**

```bash
# In a clean state, with all unrelated changes stashed:
git filter-repo --invert-paths --path .env
git filter-repo --invert-paths --path token.json

# Force-push only the *current feature branch* (NOT main).
git push --force-with-lease origin feature-branch
```

### 4b. If the secret **was already pushed** to remote

1. **Step 1 (rotate at Schwab) is what actually stopped the attacker.**
   The remaining steps preserve repo integrity but don't add security.
2. Create a security branch:

   ```bash
   git switch -c security/rotate-credentials-$(date +%Y%m%d)
   git filter-repo --invert-paths --path .env
   ```

3. Open a PR from `security/rotate-credentials-YYYYMMDD` to `main`.
   Even if you are the only reviewer, **review and merge it through
   the normal flow** — this preserves the audit trail.
4. **Do not** force-push to `main` to "hide" the leak.  GitHub still
   keeps the dangling SHA visible for months; force-push only erases
   the appearance of the issue, not its existence.
5. If you absolutely must rewrite `main` history (rare), the user must
   explicitly ack each of the following:
   - "I understand GitHub keeps dangling commit SHAs for months."
   - "I understand any cached fork or CI provider may still hold the
     secret."
   - "I have already rotated the secret in Schwab Developer Portal."
   Without all three acknowledgements, **stop** and tell the user to
   wait for a normal PR cycle.

### 5. Re-scan and verify

```bash
gitleaks detect --source . --log-opts="--all"   # exit 0
detect-secrets scan --baseline .secrets.baseline
```

### 6. Reauthorize from scratch

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
uv run python -m schwab_marketdata_mcp.health   # exit 0 = ok
```

### 7. Postmortem

Append a row to the
[Schwab Developer Portal app](https://developer.schwab.com/dashboard/apps)
audit log (or your own incident log) noting: date, root cause,
remediation actions, prevention plan.
