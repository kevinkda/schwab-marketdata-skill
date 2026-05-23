# Playbook — Shakeout analysis v2 (8 信号扫描 + AI 周报)

| Field             | Value                                                              |
| ----------------- | ------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                      |
| target_files      | `research/shakeout-YYYY-MM-DD.md` (新建)；可选 `trackers/voo-qqq-tracker.md §10` 增补行 |
| schwab tools used | `get_market_hours`, `get_quotes`, `get_price_history`, `get_cache_stats`, 必要时 `get_streaming_snapshot` |
| max tool calls    | ≤ 12（缓存命中后通常仅 4-6 次真实 API）                            |
| 模型来源          | `trackers/voo-qqq-tracker.md §10`（Tang Keyin 私有方法论；不得编造或外传） |

> **本 playbook 仅在 stock-personal 仓库内运行**。如果未在该仓库 cwd 下，
> 必须切换为只读模式：可以输出分析到聊天上下文，**禁止落盘**到任何其他仓库。

## 模型简述（来源：voo-qqq-tracker.md §10）

**Bull Market Shakeout Pattern**（牛市洗盘-突破循环）：

```
阶段 1：创新高 → 触及阻力
阶段 2：小幅回落 2-4 天（-0.5% 到 -1.5%）
阶段 3：RSI 从 75+ 降到 65-70（"修复"但仍在高位）
阶段 4：成交量萎缩（持仓者不愿卖）
阶段 5：V 形反弹突破前高
阶段 6：进入下一轮上升
```

**8 项信号扫描表**（§10.3）：

| # | 信号                    | Shakeout（应持有）阈值       | 真趋势反转（应卖出）阈值          |
| - | ----------------------- | ---------------------------- | --------------------------------- |
| 1 | Bull Trend regime       | confidence > 0.9             | 转为 Range/Bear                   |
| 2 | 价格 vs MA20            | 价格 ≥ MA20                  | 价格 < MA20                       |
| 3 | 单日 / 累计回落幅度     | > -2% 或累计 > -3%       | 单日 < -3% 连续多日               |
| 4 | 下跌日成交量            | 缩量（vs 10D 均量） | 放量（vs 10D 均量） |
| 5 | RSI(14)                 | ≥ 60                         | < 50                              |
| 6 | 重大宏观事件            | 无                           | 有（联储/地缘/财报雷）            |
| 7 | VIX                     | < 25                         | ≥ 25 或飙升                       |
| 8 | 浮盈                    | < +3%                        | ≥ +3%（考虑止盈，与反转无关）     |

**决策矩阵**：
- 1-7 项**全部命中 shakeout 列** + 8 项答"否" → **HOLD**（这是洗盘）
- 1-7 项**有 ≥ 3 项命中反转列** → **REVIEW / 减仓**
- 第 8 项命中 → **可考虑止盈**（与反转无关，独立决策）
- 其他情况 → **默认持有**

## Pre-flight (mandatory)

```text
1. get_server_info()                              # version handshake
2. health_check()                                 # token_state must be "valid"
                                                  # 顺便记录 cache_size_mb / cache_hit_rate_24h
3. get_cache_stats()                              # 决定本次能否多用缓存
4. git -C ${target_repo} config --get remote.origin.url
   → must end with kevinkda/stock-personal(.git)?
5. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   → must be true (else ASK the user; never auto-write)
6. cwd ∈ ${target_repo} subtree?  if not → 只读模式（仅输出到聊天）
7. 读取 trackers/voo-qqq-tracker.md §10 是否仍存在并可读；
   不存在或被截断 → STOP 并报告 "shakeout 模型来源缺失"
```

## Steps

### Step 1 — 选取分析标的

默认扫描 **`["VOO", "QQQ", "SPY"]`**（与 voo-qqq-tracker 对齐）。
用户也可以指定 **`TQQQ`** / **`COHR`** 或当期 watchlist 中的任何 symbol。
**最多 5 个标的** 以保持 ≤ 12 tool call 预算。

### Step 2 — 拉取价格历史（DuckDB 缓存优先）

对每个 symbol：

```text
get_price_history(
    symbol=...,
    period_type="MONTH",
    period="THREE_DAYS",      # 给 §10 模型够用即可；historical candles 永久缓存
    frequency_type="DAILY",
)
```

> **缓存语义**（v0.2 sprint 引入的 DuckDB 层）：
> - 若 `_cache_status == "hit"`：本次 candle 直接来自缓存，无 Schwab 配额消耗。
> - 若 `_cache_status == "miss"`：本次为缓存写入；下次同一窗口直接命中。
> - 历史 candle（早于 1 小时）**永久缓存**，无需重新拉取。
> - 最近 1 小时内的 candle 若超过 60 s 未刷新，缓存层会强制重新拉取，
>   保证 §10 模型用到的"今日数据"始终新鲜。

如需绕过缓存（例如怀疑数据漂移）：在 host 配置里临时设
`SCHWAB_CACHE_BYPASS=1` 跑一遍后再删掉。

### Step 3 — 拉取实时 quote 与 VIX

```text
get_quotes(symbols=["VIX", *symbols], fields=["QUOTE", "REGULAR"])
```

`VIX` 用于信号 #7；其它 quote 用于 §10 的"价格 vs MA20"和"浮盈"两栏。

> 若 VIX 无法直接 quote（部分账户限制），改用 `$VIX.X` 或 `^VIX`；都失败时
> 在报告里如实标注 "VIX 数据不可得"，并把信号 #7 标为 N/A。

### Step 4 — 在本地 DuckDB 上跑 8 项信号扫描

**完全在本地计算**，**不再触发任何 Schwab 调用**。建议生成一段
临时 Python（或在聊天里逐条算）。所有窗口数据都是 Step 2 写入的
`price_history_cache`，可通过 `Cache.query_candles(symbol, start, end)`
直接读取（详见 schwab-marketdata-mcp `cache.py`）。

每个标的输出一张 **8 行 × 4 列** 的表：

| # | 信号 | 阈值 | 实测 | 状态 |

合计每标的 1 张表 → 总共最多 5 张。

### Step 5 — 生成 AI 报告

把以下 7 项 markdown 段写入 `${target_repo}/research/shakeout-YYYY-MM-DD.md`：

1. **Frontmatter**：`generated_at` (UTC), `symbols`, `cache_hit_rate`, `mcp_version`。
2. **TL;DR**：单行结论，例如 "QQQ 7/8 项符合 shakeout → HOLD"。
3. **每个 symbol 的 8 项信号表**（Step 4 的输出）。
4. **决策矩阵**：HOLD / REVIEW / TRIM / TAKE_PROFIT。
5. **关键洞察 3 条**（基于本期数据生成；禁止照抄 §10 历史样本）。
6. **风险提示**：列举 §10.6 的 5 个失效场景中本期是否触发。
7. **数据出处与限制**：链接到 voo-qqq-tracker.md §10、本次缓存命中率、
   Schwab Market Data SOSA 不可二次分发声明。

### Step 6 — 可选：在 voo-qqq-tracker.md §10.4 表格末尾增补一行

仅在用户**明确同意**且 **VOO 或 QQQ 在本期分析中**时补一行
"shakeout 历史验证"行。不主动改动其他段落。

## Write & commit

```bash
cd ${target_repo}
# 切换到 data 分支（避免污染 main）
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c research/shakeout-$(date +%Y%m%d)
fi
mkdir -p research
# Step 5 已写入 research/shakeout-YYYY-MM-DD.md
git add research/shakeout-$(date +%Y-%m-%d).md
# 仅当 Step 6 真的改了 §10.4 时才 add
git diff --quiet trackers/voo-qqq-tracker.md \
    || git add trackers/voo-qqq-tracker.md
git commit -m "data(schwab): shakeout-v2 analysis $(date -u +%Y-%m-%d)"
# DO NOT push --force.  普通 push 到 research/data 分支即可。
```

## Acceptance criteria

完成后逐项验证（每项跑命令并确认输出，再勾选）：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit hash + `data(schwab):` 前缀的 message
- [ ] **research/ 下有当日新文件**：`ls ${target_repo}/research/shakeout-$(date +%Y-%m-%d).md`
- [ ] **仅 research/ 与 trackers/voo-qqq-tracker.md 被改动**：`git -C ${target_repo} diff --stat HEAD~1` 列出的所有文件路径都在这两个目录下
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0
- [ ] **缓存命中率 ≥ 30%**：本次 playbook 末尾再调一次 `get_cache_stats()`，`hit_rate_24h` 至少 0.3（说明缓存确实减压了 Schwab）
- [ ] **gitleaks pass**：`pre-commit run gitleaks --files <changed_files>` exit code = 0
- [ ] **报告含全部 7 段**：`grep -c '^##' ${target_repo}/research/shakeout-$(date +%Y-%m-%d).md` ≥ 7
- [ ] **无来自 §10 的逐字复制**：随机抽 1 段 §10 原文，`grep -F` 在新报告里**不应**出现完整复制（确保是 AI 生成而非搬运）

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit，保留 working tree
# 检查 working tree 后决定 git restore 或 git stash
# 如果真的需要废弃改动：
git restore research/shakeout-$(date +%Y-%m-%d).md
git restore trackers/voo-qqq-tracker.md  # 仅当 Step 6 改过
# 绝不 force-push 主分支
```

## Failure modes

| Symptom                                            | Action                                                                                          |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `voo-qqq-tracker.md §10` 不存在或被裁掉             | **STOP**。报告 "shakeout 模型来源缺失，v2 playbook 暂未实施"。**绝不编造模型**。                |
| `SchwabAuthError(reason="refresh_token_expired")`  | Stop, ask user to run `auth login_flow`.                                                        |
| `SchwabRateLimitError`                             | Wait `retry_after_seconds`，然后继续；连续两次则 STOP 并向用户汇报。                            |
| `gh repo view` 失败 / 仓库不是 private              | **STOP and refuse to write**。告诉用户问题；不绕过。                                            |
| `get_cache_stats()` 显示 cache `enabled == false`   | 仍可继续，但要在报告里注明"未启用缓存，本次全部命中 Schwab 实时 API"，并提示用户考虑打开缓存。 |
| 同一日已经存在 `research/shakeout-YYYY-MM-DD.md`     | 询问用户是否要 **覆盖** 当日 snapshot；默认 skip 并告诉用户。                                   |
| VIX 数据不可得                                     | 信号 #7 标 `N/A`，决策矩阵改用 7 项加权。**不要伪造 VIX 值**。                                  |
| Step 4 计算异常（如 candle 数据不足以算 MA20）      | 在报告里如实标"数据不足"；信号该列标 `N/A`。**不要补 0 或前向填充**。                            |
