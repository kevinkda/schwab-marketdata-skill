# Key concepts

> 11 个最常被 agent 与开发者绊住的概念，深度解释。Glossary 是字典级
> 速查；本文件给"为什么这样设计"。

## 1. access_token vs refresh_token vs OAuth code

三个 token，三种寿命，三种 rotate 行为。**绝大多数初学者**搞错的点：
以为 access_token 90 分钟到期就要走一次 OAuth；实际上 schwab-py
在 access_token 到期前用 refresh_token 自动续签，**完全无感**。
**真正需要人参与**的是 refresh_token 7 天到期时，必须重新走一次
`auth login_flow`。

详见 [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)。

## 2. TokenState 4 种 + reason 6 种

`health_check()` 返回的 `token_state` 是 **本地文件状态**（4 种）：

- `valid` — 文件存在、JSON 合法、字段齐全、权限正确
- `missing` — 文件不存在
- `malformed` — JSON 损坏 / 字段缺失
- `insecure_perms` — 权限不是 `600` / `700`

而 `SchwabAuthError(reason=...)` 是 **业务调用失败原因**（6 种）：

- `refresh_token_expired_soon`、`refresh_token_expired`
- `token_not_initialized`、`token_corrupted`
- `insecure_token_perms`、`callback_url_mismatch`

两套枚举的关系：`token_state` 看本地存档；`reason` 看运行时调 API 的
结果。前 5 种 reason 都能用 `auth login_flow` 修复；最后一种要先改
`.env`。

详见 [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md) 与
[`../troubleshooting/auth-overview.md`](../troubleshooting/auth-overview.md)。

## 3. token-bucket vs `asyncio.Semaphore`

server 用 **token-bucket + 滑动窗口**而非 `asyncio.Semaphore` 实现限流，
这是有意设计：

| 实现 | 行为 | 缺点 |
| ---- | ---- | ---- |
| `asyncio.Semaphore` | 拿不到 slot 就 await | retry sleep 期间持有 slot，**阻塞**别的并发 tool |
| **token-bucket**（当前选型） | 拿不到立即 raise `SchwabRateLimitError` | agent 自己负责重试节奏 |

token-bucket 的优势：**单个慢 tool 不阻塞别的并发 tool**。代价：agent
要做指数退避重试，不能假设 server 会自动等。

详见 [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)。

## 4. OSI option symbol（21 字符固定格式）

`{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}` —— 必须**精确 21 字符**。

- root 不足 6 字符用空格右补齐：`AAPL` → `"AAPL  "`、`BRK/B` → `"BRK/B "`
- 日期 `YYMMDD`：2024-01-19 → `240119`
- C/P：`C` 看涨，`P` 看跌
- strike：dollars × 1000，8 位整数：$170 → `00170000`、$3.5 → `00003500`

完整示例：

```
"AAPL  240119C00170000"   # AAPL 2024-01-19 Call $170.00
"BRK/B 240419P00350000"   # BRK/B 2024-04-19 Put $350.00
"SPY   251219C00500000"   # SPY  2025-12-19 Call $500.00（注意 SPY 后 3 空格）
```

OSI symbol 可直接传给 `get_quote` / `get_quotes`，但**不能**传给
`get_option_chain`（后者只接受 stock/ETF underlying）。

## 5. `get_price_history` cartesian product

`(period_type, period, frequency_type, frequency)` 四元组只接受**受限
组合**，非法组合 Schwab 服务端 silently 400。MCP server 在 Pydantic 层
提前拦截。

| period_type    | 配 frequency_type      |
| -------------- | ---------------------- |
| `DAY`          | **只能** `MINUTE`       |
| `MONTH`        | `DAILY` / `WEEKLY`      |
| `YEAR`         | `DAILY` / `WEEKLY` / `MONTHLY` |
| `YEAR_TO_DATE` | `DAILY` / `WEEKLY`      |

完整组合表见 [`../tools/tool-reference-price-history.md`](../tools/tool-reference-price-history.md)。

## 6. Pydantic Literal enum 名 vs schwab-py wire 值

公开 API **必须**传 enum 名（`"VOLUME"`、`"NASDAQ"`、`"DJI"`），
**不要**传 schwab-py wire 值（`"$DJI"`、`"day"`）。MCP server 内部翻译。

设计动机：让 agent 不用记住前缀字符（`$` / lowercase / 大小写）。直接传
wire 值会触发 `SchwabValidationError`。

完整 enum 列表在 `models.py`，按 family 分散在
[`../tools/tool-reference-*.md`](../tools/index.md) 各文件。

## 7. error normalization

所有 schwab-py 抛的异常被 server 包装成 `{"error": "Schwab*Error", ...}`
**dict 返回**，**不抛异常**穿透 MCP 协议。原因：

1. agent 端语言无关地处理结构化数据，不依赖某语言的异常机制。
2. MCP 协议本身的错误层只用于协议级失败（JSON-RPC malformed 等），
   不用于业务级失败。
3. 让 `error_recovery.md` 这种路由表能精确匹配 `error` 字段值。

agent 必须**永远先查 `error` 字段**再读 payload。

## 8. rotate-on-use refresh_token

每次刷新都签发新 refresh_token、旧的立即失效。后果：

- **不能**复制 token.json 跨机共享 —— 任一台先刷新就让其他机器失效。
- **不能**把 token.json **回退**到几小时前的备份 —— 旧 RT 已被 rotate。
- **每台机器、每个账户**单独走一次 OAuth。

这与一些 OAuth 实现不同（例如 Google API 默认 refresh_token 不 rotate）。
不要靠这种"它好像能多机用"的直觉。

## 9. 7 天**绝对**寿命

refresh_token 从**首次签发**起 7 天后服务端 invalidate，与是否使用
**无关**。意味着完全自动化（无人参与）的场景**不可能**成立 ——
Schwab 设计如此。

实务建议：cron / launchd 每 4h + 周日 20:00 + 周三 21:00 巡检 + 当
`token_expires_in_days < 12h` 时桌面通知 + 桌面 marker 文件。详见
[Quick Start Step 7](../quick-start/step-7-cron-launchd-setup.md)。

## 10. token 路径 allow-list + cloud-sync 检测

server 拒绝 token 落在非 allow-list 子目录，原因：

- 防止误把 token 写到 `~/Desktop` 或共享盘
- 防止 token 落在 iCloud / Dropbox / OneDrive 同步盘（同步过程中可能短
  暂以明文出现在 cloud server，而且 rotate-on-use 与跨机同步根本不
  兼容）

允许的根目录：`~/.local/state` 与 `~/.config`。可用 `--config-dir` 在子
目录间切换；要绕过 cloud-sync 检测必须显式
`--i-understand-cloud-sync-risk`。

## 11. Activation handshake（skill 第一步必须做）

skill 激活后第一件事必须是：

```text
get_server_info()  → 校验 server_version ∈ compatible_mcp_version
health_check()     → 校验 token_state == "valid"
```

为什么这两个 tool 是必经之路：

- `get_server_info`：保证 skill 文档与 server 实现版本兼容（避免
  agent 用旧 enum 名 / 旧字段名）。
- `health_check`：保证 token 真的可用，避免 agent 跑了一长串业务调用
  才发现 token 7 天前过期。

如果版本不匹配或 token 不 `valid`，skill 必须**立即停下**告诉用户
具体处置（不要静默 fallback）。

## 不要做的事

- **不要** 跳过 activation handshake 直接调业务 tool。
- **不要** 在 agent 侧用正则二次验证 symbol —— server 已经做了。
- **不要** 在多 agent 并发场景下假设各自独立 —— token-bucket 是 server
  进程级共享。
- **不要** 复制 token.json 给同事 / 跨机器同步。
- **不要** 把 7 天到期当成可调参数 —— 它是 Schwab 硬限制。

## 参考

- Architecture：[`architecture-overview.md`](architecture-overview.md)
- Glossary：[`glossary.md`](glossary.md)
- OSI 详解：[`osi-option-symbol.md`](osi-option-symbol.md)
