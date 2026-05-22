# Playbook — VOO / QQQ tracker update

| Field             | Value                                                              |
| ----------------- | ------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                      |
| target_files      | `docs/voo-qqq-tracker.md`                                           |
| schwab tools used | `get_quote`, `get_quotes`, `get_price_history`, `get_market_hours` |
| max tool calls    | ≤ 8                                                                 |

## Pre-flight (mandatory)

```text
1. get_server_info()                              # version handshake
2. health_check()                                 # token_state must be "valid"
3. git -C ${target_repo} config --get remote.origin.url
   → must end with kevinkda/stock-personal(.git)?
4. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   → must be true (else ASK the user; never auto-write)
5. cwd ∈ ${target_repo} subtree?  if not → 只读模式
```

## Steps

1. `get_market_hours(markets_list=["EQUITY"])` — record open/close so the
   tracker note can mark "as-of intra-day vs after-close".
2. `get_quotes(symbols=["VOO", "QQQ", "SPY"], fields=["QUOTE", "REGULAR"])`
   — current snapshot.
3. `get_price_history(symbol="VOO", period_type="MONTH",
   period="SIX_MONTHS", frequency_type="DAILY")` — last 6 months daily.
4. Repeat step 3 for `QQQ`.
5. Compute deltas vs last entry (read previous tail of
   `docs/voo-qqq-tracker.md`).
6. Append a new section to `docs/voo-qqq-tracker.md` with:
   - timestamp (TZ-aware UTC)
   - market session (open / closed / pre-/after-)
   - VOO / QQQ snapshot table
   - 1-week / 1-month / 6-month return delta
   - any notable divergence (>1% gap between VOO and QQQ over the day)

## Write & commit

```bash
cd ${target_repo}
# Switch to a data branch if currently on main:
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/schwab-$(date +%Y%m%d)
fi
git add docs/voo-qqq-tracker.md
git commit -m "data(schwab): VOO/QQQ tracker $(date -u +%Y-%m-%dT%H:%MZ)"
# DO NOT push --force.  Plain push to the data branch is fine.
```

## Acceptance criteria

完成后逐项验证（每项跑命令并确认输出，再勾选）：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit hash + `data(schwab):` 前缀的 message
- [ ] **仅 docs/ 下文件被修改**：`git -C ${target_repo} diff --stat HEAD~1` 列出的所有文件路径都以 `docs/` 开头
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0，输出 `token_state == "valid"`
- [ ] **gitleaks pass**：`pre-commit run gitleaks --files <changed_files>` exit code = 0（无密钥泄露）
- [ ] **文件 head 抽样校验**：`head -50 ${target_repo}/docs/voo-qqq-tracker.md` 看到新增 section 含
      timestamp + market session + VOO/QQQ snapshot 表格

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit 但保留 working tree 变更
# 检查是什么变更后，再决定 git restore 或 git stash
# 绝不 force-push 主分支（参见 credentials-rotate-runbook.md Git Safety Protocol §13-25）
```

## Failure modes

| Symptom                                          | Action                                                                          |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| `SchwabAuthError(reason="refresh_token_expired")`| Stop, ask user to run `auth login_flow`.                                        |
| `SchwabRateLimitError`                           | Wait `retry_after_seconds`, then continue.  If twice in a row, abort.           |
| `gh repo view` fails / repo not private          | **Stop and refuse to write.**  Tell the user; do not bypass.                     |
| Previous snapshot timestamp is < 30 minutes ago  | Politely ask the user if they really want a duplicate; default = skip.           |
