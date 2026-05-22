# Glossary

> 跨整个 skill / MCP server / Schwab API 的术语表。按主题分类。

## OAuth & 认证

| 术语 | 定义 |
| ---- | ---- |
| **App Key** | Schwab Developer Portal 创建 app 时签发的 ~32 字符客户端标识，等价于 OAuth 的 `client_id`。**不是 secret**，但实际仍要保密（暴露后任何人能用你的 app 名义发起 OAuth flow）。 |
| **App Secret** | Schwab 签发的 ~16 字符客户端凭证，等价于 OAuth 的 `client_secret`。**严禁**任何场合泄露；泄露后须立即在 Portal **Reset App Secret**。 |
| **access_token** | OAuth 调 API 时放在 `Authorization: Bearer <token>` 头里的凭证，**90 分钟**有效。schwab-py 在每次 API 调用前自动续签。 |
| **refresh_token** | 用于换新 access_token 的长期凭证，**7 天绝对寿命**到期后必须重新 `login_flow`，**不可绕过**（Schwab OAuth 设计）。 |
| **rotate-on-use** | refresh_token 每次刷新都签发新的、替换旧的；旧的立即失效。意味着不能跨机器共享 token.json。 |
| **OAuth code** | OAuth 授权流程中浏览器 redirect 回来的一次性 ~6 字符码；5 分钟过期；用 App Secret 在 token endpoint 换 access_token + refresh_token。 |
| **`login_flow`** | schwab-py 的默认 OAuth 模式；CLI 在 `127.0.0.1:8182` 起 https 监听，自动接住 redirect。 |
| **`manual_flow`** | headless OAuth 模式；CLI 打印 authorize URL，用户手动复制 redirect URL 粘回。 |
| **Callback URL** | OAuth 完成后 Schwab redirect 回的目标；必须与 `.env` 的 `SCHWAB_CALLBACK_URL` 字符级一致。 |
| **CSRF state** | OAuth 中由 schwab-py 生成的随机字符串，redirect 回来时校验，防 CSRF。 |
| **TokenState** | `health_check()` 返回的 4 个枚举：`valid` / `missing` / `malformed` / `insecure_perms`。 |

## MCP & skills

| 术语 | 定义 |
| ---- | ---- |
| **MCP** | Model Context Protocol，Anthropic 主导的 LLM tool / resource 协议。<https://modelcontextprotocol.io> |
| **MCP server** | 暴露 tool / resource 的进程；本项目里指 `schwab-marketdata-mcp`。 |
| **MCP client** | 调 MCP server 的进程；本文档里指 Cursor / Claude / 你的 Python/TS/Rust 应用。 |
| **stdio transport** | MCP 的默认传输方式，client 与 server 用 stdin/stdout 走 newline-delimited JSON-RPC。 |
| **Skill** | Cursor / Claude 的 markdown-based 知识包，含 `SKILL.md` 及 references 子目录。本仓库提供 `schwab-marketdata-ops` 与 `schwab-marketdata-workflows` 两个 skill。 |
| **`compatible_mcp_version`** | skill frontmatter 字段，约束 skill 适配的 server 版本范围（semver-like）。 |
| **`required_workspace`** | skill frontmatter 字段，约束 skill 必须在某个 cwd 子树下才能写入数据。 |
| **`language_directive`** | skill frontmatter 字段，强制 agent 用某种语言回复（本项目要求 Simplified Chinese）。 |
| **Activation handshake** | skill 激活时 agent 必须先调 `get_server_info` 校验版本范围、再调 `health_check` 校验 token 状态的两步检查。 |

## Schwab API & symbol

| 术语 | 定义 |
| ---- | ---- |
| **Market Data Production** | Schwab Developer Portal 的一个 API product，提供 quotes / price history / option chain 等只读市场数据。本 server **只用此 product**，**不**调 Trader API。 |
| **non-redistributable** | Schwab ToS 明文规定 Market Data 不可再分发；任何由本 server 拉到的数据都必须留在私有仓库 / 私有存储里。 |
| **OSI option symbol** | OCC Symbology Initiative 的 21 字符固定格式：`{ROOT:6}{YYMMDD:6}{C\|P:1}{STRIKE×1000:8}`。可直接传给 `get_quote`。 |
| **CUSIP** | 美国 9 位证券标识；`get_instrument_by_cusip` 接受。 |
| **ISIN** | 国际 12 位证券标识，美股 ISIN = `US` + 9 位 CUSIP + 1 位校验。 |
| **Cartesian product (price history)** | `get_price_history` 的 `(period_type, period, frequency_type, frequency)` 四元组只接受受限组合，非法组合服务端**静默 400**。 |
| **Pydantic Literal enum 名** | 公开 API 一律传 enum 名（`"VOLUME"`、`"NASDAQ"`、`"DJI"`），不传 schwab-py 的 wire 值（`"$DJI"`、`"day"`）。MCP server 内部翻译。 |
| **wire 值** | schwab-py 实际写到 HTTP 请求里的字符串；agent 不要直接传。 |

## 限流 & 配额

| 术语 | 定义 |
| ---- | ---- |
| **token-bucket** | 本机限流实现：bucket 容量 = `SCHWAB_RATE_LIMIT_PER_MIN`（默认 120），每请求消耗 1 slot，60s 后自动恢复。 |
| **滑动窗口** | token-bucket 的 slot 恢复方式 —— 不是每分钟 reset，而是各自 60s 后到期。 |
| **`SCHWAB_RATE_LIMIT_PER_MIN`** | 本机 bucket 容量上限，默认 120；建议设比 Schwab 服务端严（如 100）。 |
| **`SCHWAB_MAX_RETRIES`** | 429 / 5xx 自动重试次数，默认 2；测试 / CI 设为 0 让失败立即可见。 |
| **rate_limit_warning** | bucket 剩余 slot < 20 时 server 在 stderr 写一条结构化 log line：`{"event":"rate_limit_warning","remaining":N}`。 |
| **`SchwabRateLimitError`** | bucket 0 slots 或 Schwab 返回 429 时 server 返回的 error dict。 |

## 错误体系

| 术语 | 定义 |
| ---- | ---- |
| **`SchwabAuthError`** | OAuth / token 类故障；含 `reason` 字段细分（`refresh_token_expired` / `token_not_initialized` / `callback_url_mismatch` 等共 6 种）。 |
| **`SchwabRateLimitError`** | 限流故障；含 `retry_after_seconds` / `current_window_used` 字段。 |
| **`SchwabValidationError`** | Pydantic 输入验证失败；含 `field` 指向出错参数。**不消耗 Schwab 配额**。 |
| **`SchwabTransientError`** | Schwab 5xx / 网络抖动；schwab-py 已重试 `SCHWAB_MAX_RETRIES` 次仍失败。 |
| **error normalization** | 所有 schwab-py 抛的异常都被 server 包装成 `{"error": "...", ...}` dict 返回，**不抛异常**穿透 MCP 协议。 |

## 工作流 & 输出

| 术语 | 定义 |
| ---- | ---- |
| **Playbook** | `schwab-marketdata-workflows` skill 中定义的多步工作流（如 `voo-qqq-tracker-update.md`）。每个 playbook 限制 ≤ 30 个 tool call。 |
| **Pre-flight** | playbook 启动时的强制 5 步检查（version handshake / token health / cwd / repo private / idempotency）。 |
| **commit prefix `data(schwab):`** | playbook 触发的所有 commit message 必须以此前缀开头，便于审计。 |
| **`gh repo view --json isPrivate`** | playbook 写入前用 GitHub CLI 校验目标仓库是否私有，**isPrivate=false 则停**。 |
| **Idempotency window** | playbook 重复运行的时间窗（30 min 内幂等）；详见 workflows skill。 |

## 文件路径

| 术语 | 定义 |
| ---- | ---- |
| **token 路径** | `${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/token.json`；权限 `600`，父目录 `700`。 |
| **`SCHWAB_REAUTH_NEEDED.md`** | health 模块在 token 即将过期或损坏时落地到 `~/Desktop/` 的 marker 文件。 |
| **server.log** | server 的滚动日志，默认 `${XDG_STATE_HOME}/schwab-marketdata-mcp/logs/server.log`，10 MB × 5 rotated。 |
| **`.env`** | MCP 仓库根目录，含 `SCHWAB_APP_KEY` / `SCHWAB_APP_SECRET` / `SCHWAB_CALLBACK_URL`；权限 `600`；**永不入 git**。 |

## 安全

| 术语 | 定义 |
| ---- | ---- |
| **allow-list 路径** | server 拒绝 token 落在非 `~/.local/state` / `~/.config` 子目录的位置（`security.py`）。 |
| **cloud-sync detection** | server 检测 token 是否落在 iCloud / Dropbox 同步盘，触发 `SchwabAuthError(reason="cloud_path_detected")`。 |
| **`--i-understand-cloud-sync-risk`** | auth CLI 的 override flag，在你确实知道后果时绕过 cloud-sync 检测。 |
| **`gitleaks` / `detect-secrets`** | pre-commit 钩子，扫描 commit 中是否含 secret 模式。 |
| **Git Safety Protocol** | 不 force-push 主分支、不绕过 code review、不 `--no-verify` skip 钩子。 |

## 健康巡检

| 术语 | 定义 |
| ---- | ---- |
| **`schwab_marketdata_mcp.health`** | 独立可执行 module（`uv run python -m schwab_marketdata_mcp.health`），打印 health JSON，必要时写 `SCHWAB_REAUTH_NEEDED.md`。 |
| **巡检频率** | 推荐：每 4 小时 + 周日 20:00 + 周三 21:00。 |
| **`notifier-self-test.sh`** | MCP 仓库 `scripts/` 下的脚本，自检通知通道（macOS / Linux 桌面通知 + marker 文件）。 |

## 参考

- Architecture：[`architecture-overview.md`](architecture-overview.md)
- Key concepts（详细解释 11 个术语）：[`key-concepts.md`](key-concepts.md)
- OAuth 流程：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
