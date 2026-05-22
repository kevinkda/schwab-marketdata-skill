---
name: schwab-marketdata-workflows-en
compatible_mcp_version: ">=0.1,<0.2"
language_directive: "Always respond to the user in English."
required_workspace: "/opt/workspace/code/kevinkda/stock-personal"
description: |
  Use when the user asks to refresh summary.md, voo-qqq-tracker.md,
  watchlist.md, or run a shakeout-model snapshot, monthly watchlist scan,
  or option-chain research routine that depends on Schwab Market Data.
  Provides end-to-end playbooks that orchestrate multiple
  schwab-marketdata-mcp tools and write results back to project markdown
  files in the kevinkda/stock-personal repo.
  Use this skill instead of schwab-marketdata-ops-en when the task spans
  multiple tool calls and writes to markdown.
  Triggers on "update summary.md", "refresh watchlist", "shakeout
  snapshot", "VOO/QQQ tracker update", "refresh summary",
  "update watchlist".
  For these scenarios use this skill; always respond to the user in English.
---

# schwab-marketdata-workflows-en

> **License & ToS reminder** — Schwab Market Data is **non-redistributable**.
> Every markdown file written by this skill **must** stay inside the
> `kevinkda/stock-personal` private repository. Each playbook automatically
> verifies `isPrivate == true` against the locally authenticated `gh` CLI
> before writing; if the check fails, the write is refused.

## First step on activation (mandatory)

```text
1. get_server_info()  — verify server_version falls within compatible_mcp_version
2. Check the relationship between cwd and required_workspace:
   - cwd is inside the required_workspace subtree → read + write allowed
   - otherwise → only read of target_files; writes refused (prevents
     accidentally writing data into another repository)
3. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   - If it returns false / no gh CLI / not logged in → strongly
     encourage manual user confirmation; in non-interactive contexts,
     stop without writing.
```

## Playbook selection

| User intent                                | Playbook                                      |
| ------------------------------------------ | --------------------------------------------- |
| Refresh VOO/QQQ tracker                    | `playbooks/voo-qqq-tracker-update.md`         |
| Refresh watchlist snapshot (monthly/event) | `playbooks/watchlist-snapshot.md`             |
| Rewrite summary `summary.md`               | `playbooks/summary-md-refresh.md`             |
| Option-chain research (one-off deep dive)  | `playbooks/option-chain-research.md`          |

## Universal constraints (every playbook must follow)

- **Commit prefix**: every commit message produced by this skill must
  start with `data(schwab):` for audit traceability.
- **Never commit directly to main**: commit on the current `feature/data`
  branch; if the current cwd is on the main branch, first run
  `git switch -c data/schwab-YYYYMMDD`.
- **Never push to public**: a failed `gh repo view --json isPrivate`
  check stops the playbook.
- **Never `push --force`**: especially never force-push to main /
  mainline.
- **Data freshness**: when `health_check()` returns
  `token_state != "valid"` or `token_expires_in_days < 0.5`, stop and
  ask the user to reauthorize before continuing.
- **Request budget**: a single playbook invocation must stay ≤ 30 tool
  calls; beyond that, batch and tell the user. This prevents Schwab
  rate-limiting and token-bucket exhaustion.

## Idempotency

Each playbook has different repeat-run semantics; the agent must use the
table below to decide whether to skip:

| Playbook | Idempotency | Repeat-run behavior | Recommended skip condition |
| -------- | ----------- | ------------------- | -------------------------- |
| `voo-qqq-tracker-update` | **Idempotent within 30 minutes** (data freshness limit) | Each run commits one snapshot to `docs/voo-qqq-tracker.md`; multiple commits within 30 minutes pollute history | `git -C ${target_repo} log -1 --format=%ct -- docs/voo-qqq-tracker.md` is < 1800 seconds from now → skip and inform the user |
| `summary-md-refresh` | **Idempotent within 30 minutes** | Each run rewrites the `## Latest snapshot` section; multiple commits within 30 minutes pollute history | `git -C ${target_repo} log -1 --format=%ct -- docs/summary.md` is < 1800 seconds from now → skip and inform the user |
| `watchlist-snapshot` | **Not idempotent (by design)** | Each run **overwrites** the Latest snapshot section in `docs/watchlist.md`, and **overwrites** `docs/watchlist-history/<date>.md` (running again the same day overwrites it) | Typically run once a month; if you need to re-run on the same day → tell the user that today's history snapshot will be overwritten and obtain consent first |
| `option-chain-research` | **Fully repeatable** | Each run produces a **new** `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md` (named by today's date); re-running the same symbol on the same day overwrites that day's snapshot but does not pollute prior days | Same symbol same day → ask the user whether to overwrite today's snapshot; different symbol or different day → run directly |

The agent decides immediately after the playbook's pre-flight; when
skipping, it **calls no Schwab tools** (to protect the quota) and only
explains why it skipped.

## Reference

- `playbooks/voo-qqq-tracker-update.md`
- `playbooks/watchlist-snapshot.md`
- `playbooks/summary-md-refresh.md`
- `playbooks/option-chain-research.md`
