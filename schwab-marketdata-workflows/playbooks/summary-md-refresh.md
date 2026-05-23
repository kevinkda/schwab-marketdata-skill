# Playbook — `summary.md` 周更刷新（v2）

| Field             | Value                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                                    |
| target_files      | `portfolio/summary.md`（仅替换 `## 📈 周报快照（自动生成）` 段；其他全部不动）                   |
| schwab tools used | `get_market_hours`, `get_quotes`, `get_movers`, `get_price_history`, `get_cache_stats`           |
| max tool calls    | ≤ 8（缓存命中后通常 3-5 次真实 API）                                                             |
| version           | v2（v0.3 sprint, Sprint A Deliverable 2.1）                                                      |
| supersedes        | v1（≤ v0.2.x）—— v1 假设 `docs/summary.md` 路径并直接覆盖 `## Latest snapshot`                   |

> **本 playbook 仅在 stock-personal 仓库内运行**。如果当前 cwd 不在该仓库子树下，
> 必须切换为只读模式：分析输出到聊天上下文，**禁止落盘**到任何其他仓库。
>
> **v2 关键变更**（与 v1 相比）：
>
> 1. 路径从 `docs/summary.md` 改为 `portfolio/summary.md`（与用户当前实际仓库结构对齐）。
> 2. 自动生成段从 `## Latest snapshot` 改为 `## 📈 周报快照（自动生成）`，标题已显式标
>    "（自动生成）" 防止人手编辑被覆盖。
> 3. 新增 VOO / QQQ 周线趋势 + 7 日 K 线统计（用 DuckDB 缓存的 `price_history` 计算）。
> 4. 性能：所有 `get_price_history` 均默认走缓存层（v0.2 引入），周报刷新对配额冲击 ≤ 1。
> 5. 强制写入 cache hit_rate 到 frontmatter，便于检验缓存确实生效。

## 用途

每周一次（建议周五美股收盘后或周一开盘前）刷新一份**周报快照**，
让用户在 30 秒内扫到上周市场表现 + 持仓相关 ETF / index 状态。
用户的手写分析、策略复盘、TQQQ tracker 链接、纪律提醒等都在
`summary.md` 上半部分，**自动段绝不触碰**。

## Pre-flight（强制）

```text
1. get_server_info()                              # version handshake
2. health_check()                                 # token_state == "valid"
3. get_cache_stats()                              # 记录开局 hit_rate / cache_size_mb
4. git -C ${target_repo} config --get remote.origin.url
   → 必须以 kevinkda/stock-personal(.git)? 结尾
5. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   → 必须 true（否则 ASK 用户；绝不自动写）
6. cwd ∈ ${target_repo} 子树? 否 → 只读模式（仅输出到聊天）
7. ls ${target_repo}/portfolio/summary.md
   → 必须存在；不存在则 STOP（v2 不负责创建首版 summary.md）
8. grep -c '^## 📈 周报快照（自动生成）' ${target_repo}/portfolio/summary.md
   → 0 = 从未跑过 v2，本次将插入新段
   → 1 = 已有 v2 段，本次将整段替换
   → ≥ 2 = STOP，文件结构异常
```

## Steps

### Step 1 — 拉取 market hours

```text
get_market_hours(markets_list=["EQUITY", "OPTION"])
```

记录 `equity.session_state`（`open` / `closed` / `pre_market` / `after_hours`）和
下一个交易日。若 `closed` 且当日是周末，使用上一交易日 close 作为 "上周"。

### Step 2 — 拉取核心 ETF 周线（DuckDB 缓存优先）

对 `["VOO", "QQQ", "SPY", "IWM"]` 每个 symbol：

```text
get_price_history(
    symbol=...,
    period_type="MONTH",
    period="ONE_MONTH",
    frequency_type="DAILY",
)
```

> **缓存语义提示**：
>
> - 历史 candle（早于 1 小时）永久缓存，无配额消耗。
> - 最近 1 小时内的 candle 若超过 60 s 未刷新，缓存层会强制重新拉取。
> - 周报刷新通常发生在收盘后，最近 1 小时内候选普遍命中（hit_rate 期望 ≥ 70%）。

如需绕过缓存（比如怀疑数据漂移）：临时设 `SCHWAB_CACHE_BYPASS=1` 跑一遍后取消。

### Step 3 — 拉取实时 quote

```text
get_quotes(symbols=["VOO", "QQQ", "SPY", "IWM", "VIX"], fields=["QUOTE", "REGULAR"])
```

`VIX` 用于 risk gauge；其它用于 "本周末价" 列。

### Step 4 — 拉取 movers（仅一次，节省配额）

```text
get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_UP")
```

只取 top 5。下跌榜 / 成交量榜 v2 不再拉取，因为周报关注的是趋势而非单日异动；
节省的配额留给 §2 的 4 个 price_history 调用。

### Step 5 — 在本地计算

完全在本地（不再触发 Schwab 调用）：

- 周线 Δ%（最近 5 个交易日）
- 周内最高 / 最低
- 周内平均成交量
- 价格 vs 20 日 MA（用 §2 拉到的 20+ 日 candle 算）
- 7 日累计涨跌幅

### Step 6 — 末尾再调一次 `get_cache_stats()`

记录结尾 `hit_rate_24h` 和 `cache_size_mb`，写到 frontmatter，
作为 §10 acceptance criteria 第 9 项验证依据。

## 输出结构（仅替换 `## 📈 周报快照（自动生成）` 段）

```markdown
## 📈 周报快照（自动生成）

<!-- 由 schwab-marketdata-skill summary-md-refresh playbook v2 自动生成。 -->
<!-- 此段每次运行整段替换；请勿手工编辑此段内任何内容。 -->
<!-- 手写分析、策略复盘、纪律提醒请放在本段以外（上方或下方均可）。 -->

> **生成时间（UTC）**：<ISO 8601 timestamp>
> **市场状态**：<open|closed|pre_market|after_hours>
> **缓存命中率（24h）**：<hit_rate>，缓存大小：<size> MB
> **数据来源**：Schwab Market Data API（SOSA 不可二次分发）
> **MCP 版本**：<get_server_info().version>

### 核心 ETF 周线快照

| Ticker | 本周末价 | 周 Δ% | 周内高 | 周内低 | vs 20D MA | 周均成交量 |
| ------ | -------- | ----- | ------ | ------ | --------- | ---------- |
| VOO    | …        | …     | …      | …      | …         | …          |
| QQQ    | …        | …     | …      | …      | …         | …          |
| SPY    | …        | …     | …      | …      | …         | …          |
| IWM    | …        | …     | …      | …      | …         | …          |

### Risk gauge

| 指标 | 值 | 解读（机械规则；非投资建议） |
| ---- | -- | ---------------------------- |
| VIX  | …  | < 15 低波 / 15-25 中性 / ≥ 25 警觉 |

### 本周 NASDAQ 涨幅榜 Top 5

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

---
```

写入规则：

1. 若 §Pre-flight 第 8 步 grep 返回 0 → 在文件**末尾**追加该段（前置一个空行）。
2. 若返回 1 → 用 `awk` / `sed` 整段替换从 `## 📈 周报快照（自动生成）` 起到下一个
   `^##` 标题（或文件末尾）止。
3. 不得改动除该段以外的任何字节（包括末尾换行、行尾空格等）。

## 写入并提交

```bash
cd ${target_repo}

# 切换到 data 分支（避免污染 main）
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/summary-weekly-$(date +%Y%m%d)
fi

# Step 6 已写入 portfolio/summary.md（仅 ## 📈 周报快照（自动生成）段被改）
git add portfolio/summary.md
git commit -m "data(schwab): summary weekly snapshot $(date -u +%Y-%m-%dT%H:%MZ)"

# 不要 push --force；普通 push 即可，PR 走 review。
```

## Acceptance criteria

完成后逐项验证（每项跑命令并确认输出，再勾选）：

- [ ] **commit 已创建**：`git -C ${target_repo} log -1 --format="%H %s"` 输出最新 commit
      hash + `data(schwab): summary weekly snapshot` 前缀的 message。
- [ ] **仅 portfolio/summary.md 被改动**：`git -C ${target_repo} diff --stat HEAD~1`
      列出的所有文件路径都是 `portfolio/summary.md`，无其他文件。
- [ ] **diff 仅落在 §周报快照（自动生成）段**：
      `git -C ${target_repo} show HEAD --unified=0 -- portfolio/summary.md | grep '^@@'`
      所有 hunk 起点行号都位于 `## 📈 周报快照（自动生成）` 与下一个 `^##` 之间。
- [ ] **health_check 仍 valid**：`uv run python -m schwab_marketdata_mcp.health` exit code = 0。
- [ ] **§周报快照段含 4 张表（或更少，若数据缺失）**：
      `awk '/^## 📈 周报快照/,/^---$/' portfolio/summary.md | grep -c '^|'` ≥ 12
      （4 表 × 3 行表头 = 12，下限）。
- [ ] **frontmatter 含 cache hit_rate 字段**：
      `awk '/^## 📈 周报快照/,/^---$/' portfolio/summary.md | grep -c '缓存命中率'` ≥ 1。
- [ ] **gitleaks pass**：`pre-commit run gitleaks --files portfolio/summary.md` exit code = 0。
- [ ] **手写段落未被覆盖**：随机抽 1 段 §周报快照之外的原文（如 §1 账户基础信息），
      `grep -F` 在新文件里**应**仍能找到完整原文。
- [ ] **缓存命中率 ≥ 50%**：本次 playbook 末尾 `get_cache_stats()` 的 `hit_rate_24h`
      ≥ 0.5（说明缓存确实减压了 Schwab）。

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # 撤销 commit，保留 working tree 变更
# 检查 working tree 后决定 git restore 或 git stash
git restore portfolio/summary.md
# 绝不 force-push 主分支（参见 Git Safety Protocol）
```

## Failure modes

| 症状                                                       | 应对                                                                                                |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `portfolio/summary.md` 不存在                              | **STOP**。报告 "v2 不负责创建首版"，让用户先手动建初始版。                                          |
| `## 📈 周报快照（自动生成）` 段出现 ≥ 2 次                | **STOP**，提示文件结构异常，让用户先合并/清理。                                                     |
| `SchwabAuthError(reason="refresh_token_expired")`          | Stop，让用户跑 `auth login_flow`。                                                                  |
| `SchwabRateLimitError`                                     | 等 `retry_after_seconds` 后继续；连续两次 → STOP。                                                  |
| `gh repo view` 失败 / 仓库不是 private                     | **STOP and refuse to write**。告诉用户问题；不绕过。                                                |
| `get_cache_stats()` 显示 `enabled == false`                | 仍可继续，但 frontmatter 里如实写 "cache disabled"，并提示用户开启。                                |
| VIX 数据不可得                                             | risk gauge 行写 `N/A`，不要伪造 VIX 值。                                                            |
| 单一 ETF 拉不到（比如 IWM 临时停牌）                        | 该行所有数值写 `N/A`，并在末尾注明 "数据缺失：&lt;symbol&gt; @ &lt;utc&gt;"。                       |
| 已有 §周报快照段且 diff 误及其他段                         | **STOP**，把 diff dump 到聊天，提示用户先复核。                                                     |
| DuckDB lock 冲突（另一进程在用 `cache.duckdb`）            | 等待 5 s 重试一次；仍失败 → 设 `SCHWAB_CACHE_BYPASS=1` 走一次实时路径，并在 frontmatter 注明 cache miss。 |

## 与其他 playbook 的关系

- `voo-qqq-tracker-update.md`（每日，更细的 VOO/QQQ 段）—— 频率不同；周报快照不替代日报。
- `shakeout-analysis-v2.md`（按需，8 信号扫描 + 决策矩阵）—— 触发条件不同；周报是周期任务。
- `watchlist-refresh.md`（持仓表外的标的扫描）—— 数据集不同；周报只看 4 个核心 ETF。

v2 周报快照是**最低成本**的周期任务，目的是让用户每周一次"扫一眼"心里有底，
不替代任何细分 playbook。
