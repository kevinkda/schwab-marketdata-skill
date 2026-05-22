# Architecture overview

> 把 `schwab-marketdata-mcp` 的关键组件、数据流、信任边界整理在一处。

## 组件总览

```
┌────────────────────┐
│   AI agent         │  Cursor / Claude / Kiro / 自定义 SDK 客户端
│   (skills here)    │
└────────┬───────────┘
         │ MCP JSON-RPC over stdio
         ▼
┌──────────────────────────────────────────────────────────┐
│   schwab-marketdata-mcp（本仓库）                        │
│                                                          │
│   ┌──────────────┐   ┌──────────────┐   ┌─────────────┐  │
│   │ Pydantic 验证│ → │ token-bucket │ → │ schwab-py   │  │
│   │ (model.py)   │   │ (rate limit) │   │ client      │  │
│   └──────────────┘   └──────────────┘   └─────────────┘  │
│                                                  │       │
│   ┌──────────────────────────┐                   │       │
│   │ token persister          │ ◀─── access_token┘       │
│   │ (~/.local/state/...)     │     refresh on each call │
│   └──────────────────────────┘                          │
└──────────────────────────────────────────┬───────────────┘
                                           │ HTTPS / OAuth Bearer
                                           ▼
                              ┌────────────────────────┐
                              │ Schwab Market Data API │
                              │ (api.schwabapi.com)    │
                              └────────────────────────┘
```

## 5 个核心组件

| 组件 | 文件 | 职责 |
| ---- | ---- | ---- |
| **Tools** | `src/schwab_marketdata_mcp/tools/` | 12 个 outward-facing async function；每个 tool 用 Pydantic model 定义 input schema |
| **Models** | `src/schwab_marketdata_mcp/models.py` | 全部 Pydantic Literal enum 定义；提供 enum 名 ↔ schwab-py wire 值的双向翻译 |
| **Errors** | `src/schwab_marketdata_mcp/errors.py` | 4 类 `SchwabXError`：`Auth` / `RateLimit` / `Validation` / `Transient` |
| **Auth** | `src/schwab_marketdata_mcp/auth.py` + `auth_logic.py` | OAuth `login_flow` / `manual_flow` CLI；token persister；权限自检 |
| **Health** | `src/schwab_marketdata_mcp/health.py` | 独立可执行 module；返回 health JSON；触发桌面通知 |

辅助组件：

- `client.py`：薄封装的 schwab-py async client，注入 token-bucket。
- `security.py`：token 路径 allow-list、cloud-sync 检测、`chmod` 强制。
- `metrics.py`：stderr 结构化 log、`recent_error_count_24h` 计数。
- `stats.py`：token-bucket 实现。

## 数据流：一次 `get_quote` 调用

```
agent.call_tool("get_quote", {"symbol": "AAPL"})
  │
  ▼
[1] MCP server 收到 JSON-RPC tools/call
  │
  ▼
[2] tools/quotes.py: get_quote(symbol="AAPL")
  │
  ▼
[3] Pydantic 验证 symbol（UPPERCASE 正则）
  │  失败 → 立即返回 SchwabValidationError dict（不消耗配额）
  ▼
[4] token-bucket 检查 slot
  │  0 slots → 立即返回 SchwabRateLimitError（不阻塞）
  ▼
[5] schwab-py.get_quote(symbol)
  │  内部检查 access_token 寿命 → 必要时 refresh
  │  refresh 失败（7 天到期）→ SchwabAuthError
  ▼
[6] HTTP GET https://api.schwabapi.com/marketdata/v1/AAPL/quotes
  │  Authorization: Bearer <access_token>
  │  Schwab 返回 200 / 401 / 429 / 4xx / 5xx
  ▼
[7] schwab-py 解析响应 / 处理 Retry-After / 重试
  │  非 200 → 转成对应的 SchwabXError
  ▼
[8] tool 函数返回 dict（含或不含 `error` 字段）
  │
  ▼
[9] MCP server 把 dict 序列化成 result.content[0].text
  │
  ▼
agent 收到 JSON 字符串
```

## 信任边界

| 边界 | 数据 | 控制点 |
| ---- | ---- | ------ |
| Agent ↔ MCP server | symbol、enum、callback 参数 | Pydantic 拒非法输入 |
| MCP server ↔ Schwab | Bearer access_token | schwab-py 自动注入 + 自动 refresh |
| MCP server ↔ token.json | refresh_token | OS file permissions（600/700）+ allow-list 路径 |
| MCP server ↔ stderr | log lines | metrics.py 全局 mask `Bearer ...` |
| Skills ↔ Agent | 中文回复指令、版本握手指令 | language_directive + compatible_mcp_version |

## 出站 HTTP 头

每次 `api.schwabapi.com` 请求带的 header（按数据敏感度排序）：

| Header | 来源 | 含义 |
| ------ | ---- | ---- |
| `Authorization: Bearer <access_token>` | schwab-py 自动注入；access_token 来自 token.json | OAuth 鉴权；过期前 5 分钟自动 refresh |
| `User-Agent: schwab-marketdata-mcp/<ver> python/<ver> schwab-py/<ver>` | `client._inject_user_agent` 写到 `client.session.headers` | Schwab Developer Portal **Device Type** 分类依据；不写就会被分到 `Unknown` |
| `Accept: application/json` | httpx 默认 + schwab-py 显式 | 响应格式协商 |
| `Host: api.schwabapi.com` | httpx 自动 | TLS SNI / 路由 |

User-Agent 故意只携带包版本，**不**包含 username、hostname、PII；
若未来 schwab-py 把 `session.headers` 移走或改名，注入助手会
silently 退化到 httpx 默认 UA（数据路径不会因此中断）。

## 错误归一化

所有 Schwab 失败都规范化为 `{"error": "Schwab*Error", ...}` dict 返回，
**不抛异常**穿透 MCP 协议。这让 agent 始终拿到结构化数据，便于路由
处置。详见 [`error-recovery.md`](../error-recovery.md)。

## 配额与限流

- **本机**：token-bucket，默认 120 req/min，可在 `.env` 调整。slot 在
  retry sleep 期间释放（与 `asyncio.Semaphore` 的关键区别）。
- **服务端**：Schwab 不公布精确数字，社区测算 ~120 req/min/user。
- **本机优先**：把本机限流设比服务端严，避免被 Schwab 记账（持续超限
  会触发更严的服务端封锁）。

详见 [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)。

## 多机器 / 多账户

- `token.json` 是**机器局部状态**；refresh_token 是 rotate-on-use，
  无法跨机共享。
- 多机器同账户 → 每台机器跑一次 OAuth。
- 多账户 → 用 `--config-dir` 指定不同 token 路径，每个账户单独管理。

## 不要做的事

- **不要** 在 server 进程之外的代码（你自己的 Python script）里直接
  调 `schwab-py` —— 那会绕过 token-bucket 与错误归一化。
- **不要** 在多 agent 并发场景下假设各自独立 —— token-bucket 是 server
  进程级共享的，多 agent 加起来才是分钟配额。
- **不要** 把 `errors.py` 的异常类**raise** 出去 —— server 已经把它们转
  成 dict 返回；如果你 fork 了代码，保持这个 contract。

## 参考

- 12 tool index：[`../tools/index.md`](../tools/index.md)
- OAuth 流程：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
- 限流深度：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Glossary：[`glossary.md`](glossary.md)
