---
name: schwab-marketdata-ops
compatible_mcp_version: ">=0.2,<0.3"
language_directive: "Always respond to the user in Simplified Chinese (简体中文)."
auto_activate: false
activation_handshake: "get_server_info -> health_check"
compatibility: >-
  Designed for Cursor IDE >=0.45, Claude Code >=1.0, Kiro CLI >=0.1,
  Cline >=3.x, Roo Code, and other skills-compatible agents.
dependencies:
  mcp_server: "schwab-marketdata-mcp"
  external_runtime: ["uv", "python>=3.10"]
  optional_runtime: ["gh CLI (for workflows skill)", "jq (for shell ad-hoc)"]
governance:
  data_classification: "non-redistributable (Schwab Market Data)"
  written_artifacts_must_stay_in: "private repositories"
  prohibited_force_push_targets: ["main", "mainline"]
  # "master" no longer included; GitHub default has been "main" since 2020. Legacy repos should be migrated.
description: |
  Use when the user wants to call Schwab Market Data Production via the
  schwab-marketdata-mcp server, troubleshoot OAuth or 7-day refresh-token
  expiry, recover from 401/429/5xx errors, or look up the exact input/output
  schema for any of the 13 market-data tools (quotes×2, price_history,
  option_chain×2, market_hours×2, movers, search_instruments,
  get_instrument_by_cusip, health_check, get_server_info,
  get_streaming_snapshot).
  Use this skill instead of schwab-marketdata-workflows when the request is
  about a single MCP tool call or troubleshooting (not a multi-step
  playbook).
  Triggers on "Schwab quote", "Schwab price history", "Schwab option
  chain", "Schwab token expired", "reauthorize Schwab",
  "Schwab API 报错".
  对于以上场景使用本 skill；面向用户的所有回答必须使用简体中文。
---

# schwab-marketdata-ops

> **Responsibility disclaimer**: 本工具调用 Schwab Market Data
> Production API。用户须自行阅读 <https://www.schwab.com/legal/terms> 与
> <https://developer.schwab.com/legal>，并对其使用方式的合规性负全责。
> `schwab-marketdata-mcp` 与 `schwab-marketdata-skill` 的作者不对违反
> Schwab ToS 的使用承担责任。

## Activation handshake (run first)

激活本 skill 时**第一步**必须调用 `get_server_info`，确认返回的
`server_version` 落在 frontmatter `compatible_mcp_version` 范围内：

```text
get_server_info()
→ { "server_version": "0.1.x", "supported_tools": [...13 names...] }
```

若版本不匹配或调用失败：**立即停下**，告知用户升级
`schwab-marketdata-mcp` 或本 skill，**不要**继续执行业务调用。

完整握手流程（含 token 体检）：

```text
1. get_server_info()  → 校验 server_version ∈ compatible_mcp_version
2. health_check()     → 校验 token_state == "valid"
                       且 token_expires_in_days >= 0.5
3. 若任一步骤失败 → 立即停下，按 reference 修复
```

## Quick Start — 7 步从零到 hello-world

第一次接入或换台机器，按顺序读以下 7 个 step 文件：

| Step | 文件 | 期望产出 |
| ---- | ---- | -------- |
| 1 | [`references/quick-start/step-1-developer-portal-app.md`](references/quick-start/step-1-developer-portal-app.md) | Schwab Developer Portal app 已创建，App Key / Secret 已拿到 |
| 2 | [`references/quick-start/step-2-credentials-env.md`](references/quick-start/step-2-credentials-env.md) | `.env` 已填好（chmod 600），pre-commit 钩子已装 |
| 3 | [`references/quick-start/step-3-first-oauth.md`](references/quick-start/step-3-first-oauth.md) | `token.json` 已落地（chmod 600） |
| 4 | [`references/quick-start/step-4-token-health-check.md`](references/quick-start/step-4-token-health-check.md) | `health` 模块退出 0，`token_state == "valid"` |
| 5 | [`references/quick-start/step-5-first-mcp-tool-call.md`](references/quick-start/step-5-first-mcp-tool-call.md) | 最小 Python MCP client 跑通 `get_quote("VOO")` |
| 6 | [`references/quick-start/step-6-cursor-integration.md`](references/quick-start/step-6-cursor-integration.md) | `~/.cursor/mcp.json` 注册成功，agent 能调 13 个 tool |
| 7 | [`references/quick-start/step-7-cron-launchd-setup.md`](references/quick-start/step-7-cron-launchd-setup.md) | cron / launchd 健康巡检已启用，桌面通知通道已自检 |

## Common usage scenarios

仿照 helis "I want to..." 路由表，按用户意图直达对应工具与参考文档。

### "我要查实时报价"

| 场景 | 用什么 | 备注 |
| ---- | ------ | ---- |
| 单只股票 / ETF / 指数 | `get_quote("AAPL")` / `get_quote("$SPX")` | symbol 必须 UPPERCASE；指数加 `$` 前缀 |
| 批量 (≤ 50) | `get_quotes(symbols=[…])` | 超 50 自行分批，否则 `SchwabValidationError(field="symbols")` |
| 期权合约 | `get_quote("AAPL  240119C00170000")` | **OSI 21 字符**：root 6 字符（含空格右补齐）+ YYMMDD + C/P + 8 位 strike(×1000) |

→ Schema 完整定义见 [`references/tools/tool-reference-quotes.md`](references/tools/tool-reference-quotes.md)。

### "我要研究期权链"

1. `get_option_expiration_chain(symbol)` — 先取可用到期日列表
2. `get_option_chain(symbol, contract_type=…, strike_count=…, strike_range=…)` — 按 ATM/OTM/ITM 拉具体合约
3. 多步骤研究型工作流 → 转用 `schwab-marketdata-workflows` skill 的 `option-chain-research.md` playbook

→ Schema 见 [`references/tools/tool-reference-options.md`](references/tools/tool-reference-options.md)；
Greeks 时效性见 playbook Cautions 段与
[`references/concepts/osi-option-symbol.md`](references/concepts/osi-option-symbol.md)。

### "Token 过期了怎么办"

```text
1. health_check()
   → 看 token_state ∈ {"valid","missing","malformed","insecure_perms"}
   → 看 token_expires_in_days（< 0.5 强烈建议立即 reauthorize）
2. 若 SchwabAuthError(reason="refresh_token_expired" | "token_not_initialized")：
   uv run python -m schwab_marketdata_mcp.auth login_flow   # 默认
   # 或 manual_flow（headless / SSH-only / WSL2）
3. 重新 health_check() 确认 token_state == "valid"
```

→ 完整对照表与逐步处置见
[`references/troubleshooting/auth-overview.md`](references/troubleshooting/auth-overview.md)；
OAuth 流程详解见
[`references/oauth/oauth-overview.md`](references/oauth/oauth-overview.md)；
token 生命周期见
[`references/oauth/oauth-token-lifecycle.md`](references/oauth/oauth-token-lifecycle.md)。

### "限流被拒了怎么办"

| 症状 | 处置 |
| ---- | ---- |
| `SchwabRateLimitError(retry_after_seconds=N)` | 等待 N 秒后重试；连续两次告诉用户 |
| stderr 出现 `{"event":"rate_limit_warning","remaining":<20}` | 将批量请求改用 `get_quotes`（一次 50）；或降低 `SCHWAB_RATE_LIMIT_PER_MIN` |
| 0 slots 立即 raise | agent 端实施 retry-with-backoff（schwab-py 内部已重试 `SCHWAB_MAX_RETRIES` 次） |

→ token-bucket 行为与排查见
[`references/operations/rate-limit-token-bucket.md`](references/operations/rate-limit-token-bucket.md)；
4 种限流症状分流见
[`references/troubleshooting/rate-limit-overview.md`](references/troubleshooting/rate-limit-overview.md)。

### "我想看 server 健康"

```text
get_server_info()  → server_version / mcp_sdk_version / schwab_py_version / supported_tools
health_check()     → token_state / token_expires_in_days / rate_limit_remaining_per_min / recent_error_count_24h
```

两者组合即可在 30 秒内回答 "MCP server 是否健康、token 是否有效、限流是否已被吃掉"。

→ Schema 见 [`references/tools/tool-reference-meta.md`](references/tools/tool-reference-meta.md)。

### "我要把数据画 K 线 / 拉历史"

```text
get_price_history(symbol, period_type, period?, frequency_type, frequency?, ...)
```

`(period_type, period, frequency_type, frequency)` 四元组只接受
**受限组合**，非法组合服务端静默 400。MCP server 在 Pydantic 层提前
拦截。

→ Schema + 合法组合表见
[`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md)；
笛卡尔积错误处置见
[`references/troubleshooting/validation-pricehistory-cartesian.md`](references/troubleshooting/validation-pricehistory-cartesian.md)。

### "我要查 instrument 元数据 / 公司基本面"

| 场景 | 用什么 |
| ---- | ------ |
| 已知 ticker → 元数据 | `search_instruments(symbols=["AAPL"], projection="SYMBOL_SEARCH")` |
| 已知 ticker → 基本面 | `search_instruments(symbols=["AAPL"], projection="FUNDAMENTAL")` |
| 已知 9 位 CUSIP | `get_instrument_by_cusip(cusip="037833100")` |
| 公司名模糊查找 | `search_instruments(symbols=["TESLA"], projection="DESCRIPTION_SEARCH")` |

→ Schema 见 [`references/tools/tool-reference-instruments.md`](references/tools/tool-reference-instruments.md)。

### "我要看 top movers / 当日异动"

```text
get_movers(index="DJI"|"COMPX"|"SPX"|..., sort_order=..., frequency=...)
```

`index` 等枚举值必须传 enum 名（`"DJI"`），不是 wire 值（`"$DJI"`）。

→ Schema + 枚举详解见 [`references/tools/tool-reference-movers.md`](references/tools/tool-reference-movers.md)。

### "我要从自己的 Python / TypeScript / Rust 应用调"

| 客户端 | 文件 |
| ------ | ---- |
| Python（mcp SDK） | [`references/integration/python-mcp-client.md`](references/integration/python-mcp-client.md) |
| TypeScript / Node | [`references/integration/typescript-mcp-client.md`](references/integration/typescript-mcp-client.md) |
| Rust（rmcp 或自实现） | [`references/integration/rust-mcp-client.md`](references/integration/rust-mcp-client.md) |
| Shell + jq pipe | [`references/integration/cli-jq-pipe.md`](references/integration/cli-jq-pipe.md) |

## Data coverage clarifications

### `get_price_history` 就是 K 线 / candlestick 接口

如果你在找 OHLCV bar（candle / kline / candlestick），`get_price_history`
就是对应的 tool。返回结构包含 `candles[]`，每根 candle 含 `open` / `high`
/ `low` / `close` / `volume` / `datetime`（毫秒级 epoch）。

支持的粒度由 `(period_type, frequency_type, frequency)` 三元组决定：

- `period_type=DAY`：`MINUTE` × {1, 5, 10, 15, 30}（约 48 天 / 9 个月历史）
- `period_type=MONTH`：`DAILY` / `WEEKLY`（最多 6 个月）
- `period_type=YEAR`：`DAILY` / `WEEKLY` / `MONTHLY`（**最多 20 年**）
- `period_type=YEAR_TO_DATE`：`DAILY` / `WEEKLY`（年初至今）

亚分钟级 K 线（秒级、tick 级）不在 Schwab Market Data API 范围内。

→ 完整合法组合表 + 笛卡尔积错误处置见
[`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md)
与 MCP 仓库的
[README → "Data coverage clarifications"](https://github.com/kevinkda/schwab-marketdata-mcp/blob/main/README.md#data-coverage-clarifications)。

### Schwab Market Data API **不提供**的数据

以下数据在 Schwab Market Data Production API 上**架构性不可用**，需要
第三方数据源补齐：

- **Time & sales / tape（逐笔成交）** —— Schwab 2024 API 迁移移除
  `TIMESALE_*` services 后，REST 与 Streaming 都没有。
- **Tick-by-tick history（逐笔历史）** —— Schwab API 不提供。
- **Level 2 历史快照** —— 仅 Streaming，REST 无历史回放。
- **基本面 / 财报时间序列**（EPS 历史、营收历史等）—— `quotes` 带
  FUNDAMENTAL 字段但**没有**对应历史接口。
- **新闻 / SEC 文件** —— Market Data API 不提供。

各数据类的推荐第三方（Polygon.io、Tiingo、Alpaca、Databento、FMP、SEC
EDGAR）见 MCP 仓库
[README → "Data coverage clarifications"](https://github.com/kevinkda/schwab-marketdata-mcp/blob/main/README.md#data-coverage-clarifications)。

### Trader API 不在范围内

**Trader API 端点**（账户、订单、成交、持仓）显式排除在范围之外 ——
本 skill 只涵盖**只读 Market Data**。如果用户请求下单 / 修改持仓，立刻
拒绝并指向 MCP README 的 "Responsible use" 段。

## Decision tree — pick the right tool

| 用户意图                                  | 用什么 tool                                              |
| ----------------------------------------- | -------------------------------------------------------- |
| 单只股票/ETF/指数现价                     | `get_quote(symbol="AAPL")`                               |
| 一次性查多只行情（≤50）                   | `get_quotes(symbols=[...])`                              |
| 历史 K 线 / OHLC                          | `get_price_history(symbol, period_type, …)`              |
| 期权链快照                                | `get_option_chain(symbol, contract_type=…)`              |
| 期权到期日列表                            | `get_option_expiration_chain(symbol)`                    |
| 多市场开闭市状态                          | `get_market_hours(markets_list=[…])`                     |
| 单一市场开闭市状态                        | `get_market_hour_single(market_id)`                      |
| 当日 top movers                           | `get_movers(index, sort_order)`                          |
| 用 ticker 模糊查找 instrument             | `search_instruments(symbols, projection)`                |
| 用 9 位 CUSIP 精确查找                    | `get_instrument_by_cusip(cusip)`                         |
| 调试 token 状态 / 错误计数                | `health_check()`                                         |
| 取 server 元数据（版本、13 tool 列表）    | `get_server_info()`                                      |
| 实时 bid/ask/last 或 1 分钟 K 线（实验性）| `get_streaming_snapshot(symbols, service, duration_ms?)` |

**枚举值**全部用 `models.py` 中定义的 **enum 名**（如 `"VOLUME"`、
`"NASDAQ"`、`"DAY"`），MCP server 内部会翻译成 schwab-py 的 wire 值。

## Key Concepts

| 术语 | 定义 |
| ---- | ---- |
| **access_token** | Schwab OAuth bearer token，**90 分钟**有效；schwab-py 在每次 API 调用前自动续签，agent 无需关心。 |
| **refresh_token** | **rotate-on-use**：每次刷新都签发新 refresh_token，**7 天**绝对寿命到期后必须重新 `login_flow`，不可绕过（Schwab OAuth 设计如此）。 |
| **TokenState** | `health_check()` 返回的 4 个枚举：`valid`（可用） / `missing`（无 token.json） / `insecure_perms`（权限非 600/700） / `malformed`（JSON 损坏或字段缺失）。前三种由 `auth login_flow` 修复，第四种通常需要先备份再删除 token.json。 |
| **SchwabAuthError reason** | 业务调用失败时附带的细分原因枚举（6 种）：`refresh_token_expired_soon` / `refresh_token_expired` / `token_not_initialized` / `token_corrupted` / `insecure_token_perms` / `callback_url_mismatch`。每种 reason 在 [`references/troubleshooting/`](references/troubleshooting/) 有独立 5 段处置。 |
| **rate_limit_bucket** | MCP server 用 **token-bucket + 滑动窗口**（容量 = `SCHWAB_RATE_LIMIT_PER_MIN`，默认 120）而非 `asyncio.Semaphore`。区别：Semaphore 在 retry sleep 期间持有 slot，会阻塞其他并发 tool；token-bucket 在 sleep 期间释放 slot，让别的 tool 继续跑。 |
| **OSI option symbol** | 21 字符固定格式：`{ROOT:6}{YYMMDD:6}{C\|P:1}{STRIKE×1000:8}`，root 不足 6 字符用空格右补齐。例：`"AAPL  240119C00170000"` = AAPL 2024-01-19 Call $170.00；`"BRK/B 240419P00350000"`（含 `/`）。可直接传给 `get_quote`。 |
| **pricehistory cartesian product** | Schwab 对 `(period_type, period, frequency_type, frequency)` 四元组只接受**受限组合**，非法组合服务端静默返回 400。MCP server 在 Pydantic 层提前拦截，避免对计费配额的浪费。完整合法组合表见 [`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md)。 |
| **Pydantic Literal enum 名 vs wire 值** | 公开 API 一律传 **enum 名**（如 `MoversIndex.DJI` = `"DJI"`），MCP server 在内部翻译成 schwab-py 的 wire 值（如 `"$DJI"`）。这层翻译让 agent 不用记住前缀字符（`$` / `lowercase` / 大小写）。**永远不要**直接传 wire 值，否则触发 `SchwabValidationError`。 |
| **Activation handshake** | skill 激活后必经的两步：`get_server_info` 校验版本兼容、`health_check` 校验 token 状态。任一失败立即停下，不得静默 fallback。 |
| **error normalization** | 所有 schwab-py 异常被 server 包装成 `{"error": "Schwab*Error", ...}` dict 返回，**不抛异常**穿透 MCP 协议；agent 必须永远先查 `error` 字段再读 payload。 |
| **non-redistributable** | Schwab Market Data 数据不可再分发；任何 markdown / 报告写入必须留在私有仓库（workflows skill 用 `gh repo view --json isPrivate` 强制校验）。 |

## Architecture overview

```text
┌────────────────────┐
│  AI agent (this    │  Cursor / Claude / Kiro / 自定义 SDK 客户端
│  skill activates)  │
└────────┬───────────┘
         │ MCP JSON-RPC over stdio
         ▼
┌────────────────────────────────────────────┐
│  schwab-marketdata-mcp（独立仓库）          │
│  Pydantic → token-bucket → schwab-py       │
└──────────┬─────────────────────────────────┘
           │ HTTPS Bearer access_token
           ▼
┌────────────────────────┐
│ Schwab Market Data API │ api.schwabapi.com
└────────────────────────┘
```

完整架构与 5 个核心组件、数据流、信任边界见
[`references/concepts/architecture-overview.md`](references/concepts/architecture-overview.md)。

## Glossary

跨 OAuth / MCP / Schwab API / 限流 / 错误体系的术语速查见
[`references/concepts/glossary.md`](references/concepts/glossary.md)。

11 个最关键概念的 "为什么这样设计" 解释见
[`references/concepts/key-concepts.md`](references/concepts/key-concepts.md)。

## Schema cheat-sheet（详尽版按 family 拆分到 `references/tools/`）

```text
get_quote(symbol: str, fields?: list[QuoteFields])  # symbol must be UPPERCASE; "$SPX"/"AAPL  240119C00170000" also OK
get_quotes(symbols: list[str], fields?, indicative?)  # ≤50 symbols / call

get_price_history(
  symbol, period_type, period?, frequency_type, frequency?,
  start_datetime?, end_datetime?, need_extended_hours_data?, need_previous_close?
)
# Cartesian-product rules in references/tools/tool-reference-price-history.md.  TZ-aware datetimes only.

get_option_chain(symbol, contract_type?, strike_count?, ...)  # see references
get_option_expiration_chain(symbol)
get_market_hours(markets_list: list[MarketEnum], date?)
get_market_hour_single(market_id, date?)
get_movers(index, sort_order?, frequency?)
search_instruments(symbols, projection)
get_instrument_by_cusip(cusip: 9 alphanumerics)
health_check()
get_server_info()

# Experimental — bounded WebSocket snapshot (≤10 s):
get_streaming_snapshot(
  symbols: list[str],                                # ≤ 20
  service: "LEVELONE_EQUITIES" | "CHART_EQUITY",
  duration_ms: int = 2000                            # [500, 10000]
)
```

## Error normalization

所有业务 tool 在出错时**返回 dict 而非抛出**（让 agent 看到结构化数据）：

| `error` 字段                | 处置                                                                                    |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `SchwabAuthError`           | 看 `reason` → [`references/troubleshooting/auth-overview.md`](references/troubleshooting/auth-overview.md) 路由表（6 种 reason 各有独立子文件）。 |
| `SchwabRateLimitError`      | `retry_after_seconds` 后重试或降低 `SCHWAB_RATE_LIMIT_PER_MIN`。详见 [`references/troubleshooting/rate-limit-overview.md`](references/troubleshooting/rate-limit-overview.md)。 |
| `SchwabTransientError`      | Schwab 5xx/网络抖动；可短期重试，频繁出现告知用户。详见 [`references/troubleshooting/transient-errors.md`](references/troubleshooting/transient-errors.md)。 |
| `SchwabValidationError`     | 输入参数错误；详见 [`references/troubleshooting/validation-overview.md`](references/troubleshooting/validation-overview.md)。 |

完整分流索引见 [`references/error-recovery.md`](references/error-recovery.md)。

## Compatibility matrix

不同 agent 客户端对本 skill frontmatter 字段的支持情况。详细 5 客户端
× 8 字段表格见仓库根 `README.md` 的 "Compatibility matrix" 段。关键
约定：所有非标准 frontmatter 字段（`compatible_mcp_version` /
`required_workspace` / `language_directive` / `auto_activate` /
`activation_handshake` / `compatibility` / `dependencies` /
`governance`）**只是文档化约束**——真正的执行靠本 SKILL.md body 的
运行时检查（`get_server_info` 版本握手 + `cwd` 校验 + 中文回复指令）。
即便客户端不识别 frontmatter 字段，skill 行为仍正确。

## FAQ

25+ 个常见问题速查见
[`references/faq.md`](references/faq.md)（按"入门 / 安装注册 /
OAuth / 限流 / 调用 / 安全 / skill / 故障"7 类分组）。

## Reference index

按主题分类的完整 reference 文件索引，仿 helis SKILL.md 的多级表格结构。

### Quick Start (7 files)

| File | Description |
| ---- | ----------- |
| [quick-start/step-1-developer-portal-app.md](references/quick-start/step-1-developer-portal-app.md) | 注册 Schwab Developer Portal app，拿 App Key / Secret |
| [quick-start/step-2-credentials-env.md](references/quick-start/step-2-credentials-env.md) | 填 `.env`，权限 600，pre-commit 钩子 |
| [quick-start/step-3-first-oauth.md](references/quick-start/step-3-first-oauth.md) | 第一次 OAuth flow（login_flow / manual_flow） |
| [quick-start/step-4-token-health-check.md](references/quick-start/step-4-token-health-check.md) | 用 `health` 模块校验 token 真的可用 |
| [quick-start/step-5-first-mcp-tool-call.md](references/quick-start/step-5-first-mcp-tool-call.md) | 最小 MCP client 跑 `health_check` + `get_quote("VOO")` |
| [quick-start/step-6-cursor-integration.md](references/quick-start/step-6-cursor-integration.md) | 注册到 Cursor / Claude `~/.cursor/mcp.json` |
| [quick-start/step-7-cron-launchd-setup.md](references/quick-start/step-7-cron-launchd-setup.md) | cron / launchd / systemd 健康巡检自动化 |

### Tools (1 index + 8 family files)

| File | Description |
| ---- | ----------- |
| [tools/index.md](references/tools/index.md) | 13 tool 路由 + 跨 tool 公约 |
| [tools/tool-reference-quotes.md](references/tools/tool-reference-quotes.md) | `get_quote` / `get_quotes` 完整 schema |
| [tools/tool-reference-price-history.md](references/tools/tool-reference-price-history.md) | `get_price_history` + cartesian-product 合法表 |
| [tools/tool-reference-options.md](references/tools/tool-reference-options.md) | `get_option_chain` / `get_option_expiration_chain` |
| [tools/tool-reference-markets.md](references/tools/tool-reference-markets.md) | `get_market_hours` / `get_market_hour_single` |
| [tools/tool-reference-movers.md](references/tools/tool-reference-movers.md) | `get_movers` |
| [tools/tool-reference-instruments.md](references/tools/tool-reference-instruments.md) | `search_instruments` / `get_instrument_by_cusip` |
| [tools/tool-reference-meta.md](references/tools/tool-reference-meta.md) | `health_check` / `get_server_info` |
| [tools/tool-reference-streaming.md](references/tools/tool-reference-streaming.md) | `get_streaming_snapshot`（实验性） |

### OAuth (5 files)

| File | Description |
| ---- | ----------- |
| [oauth/oauth-overview.md](references/oauth/oauth-overview.md) | 端到端 3-legged OAuth 流程图 + mode 决策树 |
| [oauth/oauth-login-flow.md](references/oauth/oauth-login-flow.md) | `login_flow`（默认）详解 |
| [oauth/oauth-manual-flow.md](references/oauth/oauth-manual-flow.md) | `manual_flow`（headless / SSH-only）详解 |
| [oauth/oauth-self-host-callback.md](references/oauth/oauth-self-host-callback.md) | 自部署 callback endpoint（进阶） |
| [oauth/oauth-token-lifecycle.md](references/oauth/oauth-token-lifecycle.md) | access_token / refresh_token / OAuth code 生命周期 |
| [oauth/oauth-callback-mismatch.md](references/oauth/oauth-callback-mismatch.md) | 9 种 callback URL 不一致形态详细排查 |

### Concepts (4 files)

| File | Description |
| ---- | ----------- |
| [concepts/architecture-overview.md](references/concepts/architecture-overview.md) | 5 个核心组件、数据流、信任边界 |
| [concepts/glossary.md](references/concepts/glossary.md) | 跨域术语速查（OAuth / MCP / Schwab API / 限流 / 错误 / 工作流 / 安全 / 健康巡检） |
| [concepts/key-concepts.md](references/concepts/key-concepts.md) | 11 个最关键概念的"为什么这样设计"深度解释 |
| [concepts/osi-option-symbol.md](references/concepts/osi-option-symbol.md) | OSI 21 字符固定格式编码 / 解码 / 4 种典型违规 |

### Integration (4 files)

| File | Description |
| ---- | ----------- |
| [integration/python-mcp-client.md](references/integration/python-mcp-client.md) | 用 `mcp` Python SDK 写 MCP client（含长会话复用） |
| [integration/typescript-mcp-client.md](references/integration/typescript-mcp-client.md) | 用 `@modelcontextprotocol/sdk` 写 Node / Next.js client |
| [integration/rust-mcp-client.md](references/integration/rust-mcp-client.md) | 用 `rmcp` 或自实现 stdio + JSON-RPC |
| [integration/cli-jq-pipe.md](references/integration/cli-jq-pipe.md) | 用 shell + jq 直接 pipe stdin/stdout |

### Troubleshooting (15 files)

| File | Description |
| ---- | ----------- |
| [troubleshooting/auth-overview.md](references/troubleshooting/auth-overview.md) | 错误类型路由总入口（4 类 × 多个 reason） |
| [troubleshooting/auth-token-states.md](references/troubleshooting/auth-token-states.md) | `token_state` 4 种状态的处置与状态机 |
| [troubleshooting/auth-refresh-expiring-soon.md](references/troubleshooting/auth-refresh-expiring-soon.md) | reason=`refresh_token_expired_soon`（< 12h 预警） |
| [troubleshooting/auth-refresh-expired.md](references/troubleshooting/auth-refresh-expired.md) | reason=`refresh_token_expired`（已过期） |
| [troubleshooting/auth-token-not-initialized.md](references/troubleshooting/auth-token-not-initialized.md) | reason=`token_not_initialized`（首次安装） |
| [troubleshooting/auth-token-corrupted.md](references/troubleshooting/auth-token-corrupted.md) | reason=`token_corrupted`（JSON 损坏） |
| [troubleshooting/auth-insecure-perms.md](references/troubleshooting/auth-insecure-perms.md) | reason=`insecure_token_perms`（权限问题） |
| [troubleshooting/auth-callback-url-mismatch.md](references/troubleshooting/auth-callback-url-mismatch.md) | reason=`callback_url_mismatch`（OAuth 阶段） |
| [troubleshooting/rate-limit-overview.md](references/troubleshooting/rate-limit-overview.md) | 4 种限流症状路由 |
| [troubleshooting/rate-limit-429.md](references/troubleshooting/rate-limit-429.md) | Schwab 服务端 429 |
| [troubleshooting/rate-limit-token-bucket-empty.md](references/troubleshooting/rate-limit-token-bucket-empty.md) | 本机 token-bucket 0 slots |
| [troubleshooting/rate-limit-warning-stderr.md](references/troubleshooting/rate-limit-warning-stderr.md) | `rate_limit_warning` 预警（仍成功） |
| [troubleshooting/rate-limit-no-retry-after.md](references/troubleshooting/rate-limit-no-retry-after.md) | 429 缺 `Retry-After` 头（罕见） |
| [troubleshooting/validation-overview.md](references/troubleshooting/validation-overview.md) | Pydantic 输入验证错误路由 |
| [troubleshooting/validation-symbol.md](references/troubleshooting/validation-symbol.md) | symbol 正则不匹配 |
| [troubleshooting/validation-pricehistory-cartesian.md](references/troubleshooting/validation-pricehistory-cartesian.md) | price history 笛卡尔积非法 |
| [troubleshooting/validation-batch-50.md](references/troubleshooting/validation-batch-50.md) | `get_quotes` 超 50 symbol |
| [troubleshooting/validation-osi-format.md](references/troubleshooting/validation-osi-format.md) | OSI option 格式错 |
| [troubleshooting/transient-errors.md](references/troubleshooting/transient-errors.md) | `SchwabTransientError`（5xx / 4xx 边角） |

### Operations (3 files)

| File | Description |
| ---- | ----------- |
| [operations/rate-limit-token-bucket.md](references/operations/rate-limit-token-bucket.md) | token-bucket 实现深度 + 调优策略 |
| [operations/observability-and-caching.md](references/operations/observability-and-caching.md) | server.log / health 字段 + agent 端缓存策略 |
| [operations/multi-machine-multi-account.md](references/operations/multi-machine-multi-account.md) | 多机器 / 多账户的正确做法 |

### Top-level (5 files)

| File | Description |
| ---- | ----------- |
| [error-recovery.md](references/error-recovery.md) | 错误体系总览 + 决策流程 |
| [rate-limits-and-paging.md](references/rate-limits-and-paging.md) | 限流 + paging 综合 |
| [credentials-rotate-runbook.md](references/credentials-rotate-runbook.md) | 凭证泄露应急 runbook（先 Schwab Reset Secret，再清仓） |
| [tos-snapshot.md](references/tos-snapshot.md) | Schwab ToS 关键节选（不可再分发） |
| [faq.md](references/faq.md) | 25+ 常见问题速查 |
