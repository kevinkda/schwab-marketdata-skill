# Playbook — `summary.md` refresh

| Field             | Value                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                  |
| target_files      | `docs/summary.md`                                                              |
| schwab tools used | `get_quote`, `get_quotes`, `get_movers`, `get_market_hours`                    |
| max tool calls    | ≤ 10                                                                            |

## Purpose

Produce a one-page "what happened today" summary for the user's
personal-investing repo.  It is intended to be **scannable in 30
seconds**, not exhaustive — so the playbook deliberately limits the
number of tool calls.

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Steps

1. `get_market_hours(markets_list=["EQUITY", "OPTION"])` — record session.
2. `get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_UP")` — top
   gainers.
3. `get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_DOWN")` — top
   losers.
4. `get_movers(index="NYSE", sort_order="VOLUME")` — high-volume names.
5. `get_quotes(symbols=["VOO", "QQQ", "SPY", "IWM"], fields=["QUOTE", "REGULAR"])` — market headline tickers.

## Output structure (`docs/summary.md`)

Replace the `## Latest snapshot` section (preserve any other narrative
sections the user has hand-written above / below):

```markdown
## Latest snapshot

_Updated <UTC timestamp>; market session: <open|closed|pre-|after->_

### Market headlines

| Ticker | Price | Day Δ | Day Δ% |
| ------ | ----- | ----- | ------ |
| VOO    | …     | …     | …      |
| QQQ    | …     | …     | …      |
| SPY    | …     | …     | …      |
| IWM    | …     | …     | …      |

### Top gainers (NASDAQ)

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

### Top losers (NASDAQ)

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

### High volume (NYSE)

| Symbol | Last | Vol |
| ------ | ---- | --- |
| …      | …    | …   |
```

## Write & commit

```bash
cd ${target_repo}
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/summary-$(date +%Y%m%d)
fi
git add docs/summary.md
git commit -m "data(schwab): summary refresh $(date -u +%Y-%m-%dT%H:%MZ)"
```

## Acceptance criteria

完成后逐项验证：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit hash + `data(schwab):` 前缀的 message
- [ ] **仅 docs/ 下文件被修改**：`git -C ${target_repo} diff --stat HEAD~1` 列出的所有文件路径都以 `docs/` 开头（应仅 `docs/summary.md`）
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0，输出 `token_state == "valid"`
- [ ] **gitleaks pass**：`pre-commit run gitleaks --files docs/summary.md` exit code = 0
- [ ] **文件 head 抽样校验**：`head -50 ${target_repo}/docs/summary.md` 看到新的 `## Latest snapshot` 段含
      timestamp / market session / VOO|QQQ|SPY|IWM 表格；用户手写 narrative 段未被覆盖

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit 但保留 working tree 变更
# 检查是什么变更后，再决定 git restore 或 git stash
# 绝不 force-push 主分支（参见 credentials-rotate-runbook.md Git Safety Protocol §13-25）
```

## Tone

The narrative section above the snapshot table is **user-authored** and
must NOT be overwritten by this playbook.  Treat anything outside the
`## Latest snapshot` heading as untouchable.
