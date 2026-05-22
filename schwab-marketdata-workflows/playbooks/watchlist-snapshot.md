# Playbook — Watchlist snapshot

| Field             | Value                                                                |
| ----------------- | -------------------------------------------------------------------- |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                        |
| target_files      | `docs/watchlist.md` (and optionally `docs/watchlist-history/<date>.md`) |
| schwab tools used | `get_quotes`, `search_instruments`, `get_market_hour_single`         |
| max tool calls    | ≤ 12 (split if watchlist > 50 symbols)                                |

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Inputs

The playbook reads `docs/watchlist.md` and parses the symbol list from
the first markdown table (column "Symbol").  If parsing finds 0 symbols,
**stop** and ask the user where the canonical list lives — do not
autogenerate one from elsewhere.

## Steps

1. Parse the watchlist into a Python list `symbols: list[str]`
   (uppercase normalize, drop blanks).
2. If `len(symbols) > 50`, split into batches of ≤50.  For each batch:
   `get_quotes(symbols=batch, fields=["QUOTE", "FUNDAMENTAL", "REGULAR"])`.
3. `get_market_hour_single(market_id="EQUITY")` — record session.
4. For each symbol whose `lastPrice` deviates >5% from the previous
   snapshot (look up the most recent
   `docs/watchlist-history/*.md` file), call
   `search_instruments(symbols=[that_one], projection="FUNDAMENTAL")`
   to enrich with fundamentals.  **Cap this enrichment at 5 symbols
   per snapshot** to stay under the per-call budget.
5. Build a markdown table sorted by `netPercentChange` desc.
6. Write to:
   * `docs/watchlist.md` — replace the "Latest snapshot" section.
   * `docs/watchlist-history/YYYY-MM-DD.md` — full snapshot copy with
     timestamp.

## Write & commit

```bash
cd ${target_repo}
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/watchlist-$(date +%Y%m%d)
fi
git add docs/watchlist.md docs/watchlist-history/$(date -u +%Y-%m-%d).md
git commit -m "data(schwab): watchlist snapshot $(date -u +%Y-%m-%dT%H:%MZ)"
```

## Acceptance criteria

完成后逐项验证：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit hash + `data(schwab):` 前缀的 message
- [ ] **仅 docs/ 下文件被修改**：`git -C ${target_repo} diff --stat HEAD~1` 列出的所有文件路径都以 `docs/` 开头（含 `docs/watchlist.md` 与 `docs/watchlist-history/<date>.md`）
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0，输出 `token_state == "valid"`
- [ ] **gitleaks pass**：`pre-commit run gitleaks --files <changed_files>` exit code = 0
- [ ] **文件 head 抽样校验**：`head -50 ${target_repo}/docs/watchlist.md` 看到新的 "Latest snapshot" 段；`head -50 ${target_repo}/docs/watchlist-history/$(date -u +%Y-%m-%d).md` 看到完整月度 snapshot

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit 但保留 working tree 变更
# 检查是什么变更后，再决定 git restore 或 git stash
# 绝不 force-push 主分支（参见 credentials-rotate-runbook.md Git Safety Protocol §13-25）
```

## Sanity assertions before commit

* `git diff --cached --stat` should show ≤ 2 files changed.
* No file outside `docs/` is staged.
* `gitleaks protect --staged` passes (pre-commit hook will catch this
  too, but assert explicitly so a misconfigured repo can't sneak
  through).
