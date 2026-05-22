# Quick Start — Step 2: Configure `.env` & local credentials

> **Goal**: Write the App Key / App Secret / Callback URL obtained in
> Step 1 into the `.env` at the root of the `schwab-marketdata-mcp`
> repo, and verify that the pre-commit hook blocks any commit of
> `.env`.

## Prerequisites

- [ ] Step 1 completed and you have the App Key / Secret
- [ ] You have `git clone https://github.com/kevinkda/schwab-marketdata-mcp`
      to your machine (or your own private fork)
- [ ] `uv` installed (<https://docs.astral.sh/uv/getting-started/installation/>)

## Steps

```bash
cd /path/to/schwab-marketdata-mcp

# 1) Copy from the template (never edit .env.example then rename)
cp .env.example .env
chmod 600 .env

# 2) Edit the three non-optional fields in .env
$EDITOR .env

# 3) Install project dependencies (schwab-py, mcp, httpx, ...)
uv sync

# 4) Install pre-commit hooks (gitleaks + detect-secrets — prevents
#    accidentally committing .env)
uv run pre-commit install
```

`.env` needs **at least** three lines (other fields can stay
commented):

```bash
SCHWAB_APP_KEY=<32-char App Key>
SCHWAB_APP_SECRET=<16-char App Secret>
SCHWAB_CALLBACK_URL=https://127.0.0.1:8182
```

`SCHWAB_CALLBACK_URL` must be **byte-identical** to the Callback URL
registered on the Developer Portal in Step 1 (a single missing `/`,
port, or protocol counts as different).

## Expected outcome

- `.env` exists with mode `600`
- All three fields populated with real values (the
  `dummy-not-a-real-secret` placeholder is gone)
- `pre-commit` hook installed at `.git/hooks/pre-commit`
- `uv sync` exited 0, `.venv/` was generated

## Verification checklist

- [ ] `stat -c '%a %n' .env` (macOS: `stat -f '%A %N' .env`) = `600 .env`
- [ ] `grep -c 'dummy-not-a-real-secret' .env` = `0` (all placeholder
      strings replaced)
- [ ] `uv run pre-commit run --all-files` exits 0 (all hooks pass)
- [ ] **Deliberately attempt to commit `.env`** (drill only):

  ```bash
  git add -f .env  # -f because .gitignore already blocks it
  git commit -m "test"  # should be blocked by gitleaks
  git restore --staged .env  # undo
  ```

  Expected: `gitleaks` fails immediately and the commit is rejected.
- [ ] `python -m schwab_marketdata_mcp.auth login_flow --dry-run`
      (does not open the browser) prints `Callback URL: https://127.0.0.1:8182`
      and matches the value registered on the Portal.

## Common failures

| Symptom | Fix |
| ------- | --- |
| `.env` mode is `644` or `664` | `chmod 600 .env`; the server will refuse to start otherwise |
| `.env` is tracked by git | `git rm --cached .env`, then immediately go back to [Step 1](step-1-developer-portal-app.md) and **rotate the App Secret**, then follow [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md) |
| `pre-commit install` can't find `pre-commit` | Run `uv sync` first to install dev deps; or `pip install pre-commit` |
| `.env` has a trailing `/` on `SCHWAB_CALLBACK_URL` | Make it identical to the Portal value; OAuth fails CSRF validation at the callback step otherwise |
| `uv sync` reports `python>=3.10` not found | Install a Python ≥ 3.10 (3.11 or 3.12 recommended) |

## What not to do

- **Do not** copy `.env` into iCloud / Dropbox / OneDrive sync folders.
- **Do not** paste the App Secret into chat apps, issue trackers, or
  PR descriptions.
- **Do not** `git push origin main` on a public repo (or even a private
  fork) without first manually confirming `git status` does not show
  `.env`.

## Next step

→ [Step 3: First OAuth flow](step-3-first-oauth.md)

## References

- Full `.env.example` template: see the MCP repo's `/.env.example`
- pre-commit configuration: see the MCP repo's `.pre-commit-config.yaml`
- Credential-leak emergency runbook: [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
