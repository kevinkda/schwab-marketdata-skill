---
name: schwab-marketdata-ops
compatible_mcp_version: ">=0.1,<0.2"
language_directive: "Always respond to the user in Simplified Chinese (简体中文)."
description: |
  Use when the user wants to call Schwab Market Data Production via the
  schwab-marketdata-mcp server, troubleshoot OAuth or 7-day refresh-token
  expiry, recover from 401/429/5xx errors, or look up the exact input/output
  schema for any of the 12 market-data tools (quotes×2, price_history,
  option_chain×2, market_hours×2, movers, search_instruments,
  get_instrument_by_cusip, health_check, get_server_info).
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
→ { "server_version": "0.1.x", "supported_tools": [...12 names...] }
```

若版本不匹配或调用失败：**立即停下**，告知用户升级
`schwab-marketdata-mcp` 或本 skill，**不要**继续执行业务调用。

## Common usage scenarios

仿照 helis "I want to..." 路由表，按用户意图直达对应工具与参考文档。

### "我要查实时报价"

| 场景 | 用什么 | 备注 |
| ---- | ------ | ---- |
| 单只股票 / ETF / 指数 | `get_quote("AAPL")` / `get_quote("$SPX")` | symbol 必须 UPPERCASE；指数加 `$` 前缀 |
| 批量 (≤ 50) | `get_quotes(symbols=[…])` | 超 50 自行分批，否则 `SchwabValidationError(field="symbols")` |
| 期权合约 | `get_quote("AAPL  240119C00170000")` | **OSI 21 字符**：root 6 字符（含空格右补齐）+ YYMMDD + C/P + 8 位 strike(×1000) |

→ Schema 完整定义见 `references/tool-reference.md` §1-2。

### "我要研究期权链"

1. `get_option_expiration_chain(symbol)` — 先取可用到期日列表
2. `get_option_chain(symbol, contract_type=…, strike_count=…, strike_range=…)` — 按 ATM/OTM/ITM 拉具体合约
3. 多步骤研究型工作流 → 转用 `schwab-marketdata-workflows` skill 的 `option-chain-research.md` playbook

→ Schema 见 `references/tool-reference.md` §4-5；Greeks 时效性见 playbook Cautions 段。

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

→ 完整对照表与逐步处置见 `references/troubleshooting-auth.md`；OAuth 流程详解见 `references/oauth-flow.md`。

### "限流被拒了怎么办"

| 症状 | 处置 |
| ---- | ---- |
| `SchwabRateLimitError(retry_after_seconds=N)` | 等待 N 秒后重试；连续两次告诉用户 |
| stderr 出现 `{"event":"rate_limit_warning","remaining":<20}` | 将批量请求改用 `get_quotes`（一次 50）；或降低 `SCHWAB_RATE_LIMIT_PER_MIN` |
| 0 slots 立即 raise | agent 端实施 retry-with-backoff（schwab-py 内部已重试 `SCHWAB_MAX_RETRIES` 次） |

→ token-bucket 行为与排查见 `references/rate-limits-and-paging.md` 的 Troubleshooting 段。

### "我想看 server 健康"

```text
get_server_info()  → server_version / mcp_sdk_version / schwab_py_version / supported_tools
health_check()     → token_state / token_expires_in_days / rate_limit_remaining_per_min / recent_error_count_24h
```

两者组合即可在 30 秒内回答 "MCP server 是否健康、token 是否有效、限流是否已被吃掉"。

→ Schema 见 `references/tool-reference.md` §11-12。

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
| 取 server 元数据（版本、12 tool 列表）    | `get_server_info()`                                      |

**枚举值**全部用 `models.py` 中定义的 **enum 名**（如 `"VOLUME"`、
`"NASDAQ"`、`"DAY"`），MCP server 内部会翻译成 schwab-py 的 wire 值。

## Key Concepts

| 术语 | 定义 |
| ---- | ---- |
| **access_token** | Schwab OAuth bearer token，**90 分钟**有效；schwab-py 在每次 API 调用前自动续签，agent 无需关心。 |
| **refresh_token** | **rotate-on-use**：每次刷新都签发新 refresh_token，**7 天**绝对寿命到期后必须重新 `login_flow`，不可绕过（Schwab OAuth 设计如此）。 |
| **TokenState** | `health_check()` 返回的 4 个枚举：`VALID`（可用） / `MISSING`（无 token.json） / `INSECURE_PERMS`（权限非 600/700） / `MALFORMED`（JSON 损坏或字段缺失）。前三种由 `auth login_flow` 修复，第四种通常需要先备份再删除 token.json。 |
| **rate_limit_bucket** | MCP server 用 **token-bucket + 滑动窗口**（容量 = `SCHWAB_RATE_LIMIT_PER_MIN`，默认 120）而非 `asyncio.Semaphore`。区别：Semaphore 在 retry sleep 期间持有 slot，会阻塞其他并发 tool；token-bucket 在 sleep 期间释放 slot，让别的 tool 继续跑。 |
| **OSI option symbol** | 21 字符固定格式：`{ROOT:6}{YYMMDD:6}{C\|P:1}{STRIKE×1000:8}`，root 不足 6 字符用空格右补齐。例：`"AAPL  240119C00170000"` = AAPL 2024-01-19 Call $170.00；`"BRK/B 240419P00350000"`（含 `/`）。可直接传给 `get_quote`。 |
| **pricehistory cartesian product** | Schwab 对 `(period_type, period, frequency_type, frequency)` 四元组只接受**受限组合**，非法组合服务端静默返回 400。MCP server 在 Pydantic 层提前拦截，避免对计费配额的浪费。完整合法组合表见 `references/tool-reference.md` §3。 |
| **Pydantic Literal enum 名 vs wire 值** | 公开 API 一律传 **enum 名**（如 `MoversIndex.DJI` = `"DJI"`），MCP server 在内部翻译成 schwab-py 的 wire 值（如 `"$DJI"`）。这层翻译让 agent 不用记住前缀字符（`$` / `lowercase` / 大小写）。**永远不要**直接传 wire 值，否则触发 `SchwabValidationError`。 |

## Schema cheat-sheet（详尽版见 `references/tool-reference.md`）

```text
get_quote(symbol: str, fields?: list[QuoteFields])  # symbol must be UPPERCASE; "$SPX"/"AAPL  240119C00170000" also OK
get_quotes(symbols: list[str], fields?, indicative?)  # ≤50 symbols / call

get_price_history(
  symbol, period_type, period?, frequency_type, frequency?,
  start_datetime?, end_datetime?, need_extended_hours_data?, need_previous_close?
)
# Cartesian-product rules in references/tool-reference.md.  TZ-aware datetimes only.

get_option_chain(symbol, contract_type?, strike_count?, ...)  # see references
get_option_expiration_chain(symbol)
get_market_hours(markets_list: list[MarketEnum], date?)
get_market_hour_single(market_id, date?)
get_movers(index, sort_order?, frequency?)
search_instruments(symbols, projection)
get_instrument_by_cusip(cusip: 9 alphanumerics)
health_check()
get_server_info()
```

## Error normalization

所有业务 tool 在出错时**返回 dict 而非抛出**（让 agent 看到结构化数据）：

| `error` 字段                | 处置                                                                                    |
| --------------------------- | --------------------------------------------------------------------------------------- |
| `SchwabAuthError`           | 看 `reason` → `references/error-recovery.md` 的对照表。最常见是 `refresh_token_expired`。 |
| `SchwabRateLimitError`      | `retry_after_seconds` 后重试或降低 `SCHWAB_RATE_LIMIT_PER_MIN`。详见 rate-limits 文档。 |
| `SchwabTransientError`      | Schwab 5xx/网络抖动；可短期重试，频繁出现告知用户。                                      |
| `SchwabValidationError`     | 输入参数错误（你这边检查 symbol 格式 / cartesian product / 长度上限 50）。              |

## Reference index

| File | Description | When to read |
| ---- | ----------- | ------------ |
| `references/oauth-flow.md` | OAuth 3-legged 流程、`login_flow` vs `manual_flow` 决策树、token 路径与生命周期 | 首次接入、需要重新授权、headless / WSL2 环境 |
| `references/tool-reference.md` | 12 tool 完整 schema（参数类型、枚举值、组合约束） | 拼调用参数、对照 Pydantic 错误信息 |
| `references/troubleshooting-auth.md` | 6 种 `SchwabAuthError(reason=…)` 的 symptom / root cause / 诊断 / 修复 / 验证 5 段处置 | 401 / token 过期 / 权限异常 / callback 配置错 |
| `references/troubleshooting-rate-limit.md` | 429 / `SchwabRateLimitError` / token-bucket 0 slots / 缺 `Retry-After` 头 4 个症状的处置 | 出现 429、批量查询被拒、并发量打满 |
| `references/troubleshooting-validation.md` | `SchwabValidationError` 各种来源的处置（symbol 正则、pricehistory 笛卡尔积、>50 symbol、OSI 格式） | Pydantic 拒绝输入参数 |
| `references/error-recovery.md` | 上述 3 个 troubleshooting 文件的索引（按错误类型分流） | 不确定错误类型时的入口 |
| `references/rate-limits-and-paging.md` | token-bucket 行为详解、Retry-After 处理、批量分页策略 | 优化高并发 / 批量任务 |
| `references/credentials-rotate-runbook.md` | 凭证泄露应急 runbook（创建 security 分支、PR 审查、**不 force-push 主分支**） | App Key / Secret 疑似泄露 |
| `references/tos-snapshot.md` | Schwab SOSA 关键段落存档（不可再分发、私有仓约束） | 与用户讨论数据共享 / 公开发布合规性 |
