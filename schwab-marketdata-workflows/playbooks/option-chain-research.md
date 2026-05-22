# Playbook — Option chain research (single underlying)

| Field             | Value                                                                                |
| ----------------- | ------------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                        |
| target_files      | `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md`                                       |
| schwab tools used | `get_quote`, `get_option_expiration_chain`, `get_option_chain`                       |
| max tool calls    | ≤ 6                                                                                   |

## Purpose

Snapshot the option chain for one underlying (e.g. `AAPL`, `QQQ`) for
research / journaling.  Designed to be a single, contained note — not a
real-time monitor (use the streaming API for that, which this server
does NOT expose).

## Inputs

- `symbol` — single ticker; reject anything that does not match
  `^[A-Z][A-Z0-9.\-/]{0,9}$` (no indices, no OSI strings).
- `from_date` / `to_date` — optional TZ-aware datetimes for the chain
  window.  Default: today → today + 60 days.

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Steps

1. `get_quote(symbol)` — capture the underlying price for ATM context.
2. `get_option_expiration_chain(symbol)` — list available expiries.
3. Pick up to 2 expiries within `[from_date, to_date]`:
   - the **nearest monthly** (3rd Friday of the next month)
   - the **next quarterly** (Mar/Jun/Sep/Dec)
4. For each picked expiry, call `get_option_chain` with:

   ```text
   contract_type="ALL"
   strike_count=20
   include_underlying_quote=False  # already have it from step 1
   strategy="SINGLE"
   strike_range="NEAR_THE_MONEY"
   from_date=<picked_expiry>
   to_date=<picked_expiry>
   ```

   This produces ~20 strikes around the money for that expiry, both
   calls and puts.
5. Build a markdown report in
   `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md` with:
   - underlying snapshot (from step 1)
   - one section per expiry showing a calls/puts table sorted by strike

## Write & commit

```bash
cd ${target_repo}
mkdir -p docs/option-research
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/options-${SYMBOL,,}-$(date +%Y%m%d)
fi
git add docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md
git commit -m "data(schwab): ${SYMBOL} option chain research $(date -u +%Y-%m-%d)"
```

## Acceptance criteria

完成后逐项验证：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit hash + `data(schwab):` 前缀的 message
- [ ] **仅 docs/ 下文件被修改**：`git -C ${target_repo} diff --stat HEAD~1` 列出的所有文件路径都以
      `docs/option-research/` 开头（应仅 `docs/option-research/${SYMBOL}-<date>.md`）
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0，输出 `token_state == "valid"`
- [ ] **gitleaks pass**：
      `pre-commit run gitleaks --files docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md`
      exit code = 0
- [ ] **文件 head 抽样校验**：
      `head -50 ${target_repo}/docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md`
      看到 underlying snapshot + 至少 1 个 expiry section（含 calls/puts strike 表格 + UTC timestamp）

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit 但保留 working tree 变更
# 检查是什么变更后，再决定 git restore 或 git stash
# 绝不 force-push 主分支（参见 credentials-rotate-runbook.md Git Safety Protocol §13-25）
```

## Cautions

- The Greeks (`delta`, `gamma`, `theta`, `vega`) returned by Schwab are
  computed against their pricing model.  **Document the exact moment**
  (UTC + market session) you took the snapshot — values shift
  meaningfully over a single trading hour.
- Chain data is non-redistributable per Schwab ToS.  If the user asks
  to share this note, refuse and remind them per
  `references/tos-snapshot.md`.
