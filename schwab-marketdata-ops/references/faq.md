# FAQ

> 25+ 个最常被问到的问题与简短答案。详细讨论指向相应 reference 文件。

## 入门

### 1. 这个 skill 是做什么的？

把 [`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp)
server 暴露的 12 个 Schwab Market Data tool（quotes / price history /
option chain / movers / instruments / health / server_info）的使用方式、
错误处置、OAuth 流程、playbook 编排打包成 Cursor / Claude / Kiro CLI 等
agent 可加载的 skill。Skill 本身是**只读文档包**，所有 tool call 由 MCP
server 实际执行。

### 2. 与 Schwab 官方 SDK 是什么关系？

Schwab 没有官方 Python SDK。`schwab-marketdata-mcp` 内部用
[`schwab-py`](https://github.com/alexgolec/schwab-py)（社区维护的非官方
Python 客户端）。本 skill 不直接依赖 schwab-py，只通过 MCP 调
schwab-marketdata-mcp。

### 3. 我可以分发拉到的数据吗？

**不可以**。Schwab Market Data 是 **non-redistributable**（详见
[`tos-snapshot.md`](tos-snapshot.md)）。`schwab-marketdata-workflows`
skill 在写入 markdown 前会用 `gh repo view --json isPrivate` 验证
仓库私有。

## 安装与注册

### 4. 我需要先有 Schwab 账户吗？

需要。必须是 Schwab **Brokerage** 账户（不是 Schwab Bank-only），并在
[Schwab Developer Portal](https://developer.schwab.com/) 注册一个 app
拿 App Key / Secret。详见
[`quick-start/step-1-developer-portal-app.md`](quick-start/step-1-developer-portal-app.md)。

### 5. App 审批要多久？

通常 1-3 工作日；偶尔积压到 5 天。

### 6. 必须用 `uv` 吗？能用 pip / poetry 吗？

**`uv` 是推荐**（仓库依赖锁文件 `uv.lock`），但只要你能用 `pip install
-e .` + `pip install -r requirements*.txt` 起服务也可以。`mcp.json`
里的 `command` 改成对应 binary 即可。

### 7. Windows 支持吗？

**v0.1 不支持 Windows**。`platform_supported_v1` = `["macos>=11", "linux"]`。
原因：tokenfile permission 与 cron / launchd 的健康巡检还没移植。WSL2
（Linux subsystem）可以用。

## OAuth & token

### 8. refresh_token 7 天到期能延长吗？

不能。这是 Schwab OAuth 的硬限制。任何客户端方式（schwab-py、本 server、
任何 fork）都无法绕过。详见
[`oauth/oauth-token-lifecycle.md`](oauth/oauth-token-lifecycle.md)。

### 9. 我能完全自动化（无人值守）吗？

**不能**。每 7 天必须人参与一次 `auth login_flow`。可以用 cron + 桌面
通知最大化窗口（详见
[`quick-start/step-7-cron-launchd-setup.md`](quick-start/step-7-cron-launchd-setup.md)）。

### 10. 我能把 token.json 复制到另一台机吗？

**不能**。refresh_token 是 rotate-on-use，跨机不兼容。每台机器单独走
OAuth。详见
[`operations/multi-machine-multi-account.md`](operations/multi-machine-multi-account.md)。

### 11. `login_flow` vs `manual_flow` 怎么选？

普通笔记本用 `login_flow`（默认）；SSH-only / 容器 / WSL2 用
`manual_flow`。详见
[`oauth/oauth-overview.md`](oauth/oauth-overview.md)。

### 12. 浏览器跳出 SSL 错误怎么办？

`login_flow` 用自签证书，浏览器一定会警告。点 Advanced → Proceed 即可。
详见 [`oauth/oauth-login-flow.md`](oauth/oauth-login-flow.md)。

## 限流

### 13. 每分钟最多多少请求？

社区测算 ~120 req/min/user。本 server 默认
`SCHWAB_RATE_LIMIT_PER_MIN=120`。详见
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md)。

### 14. 拿不到 slot 时 server 会等吗？

**不会**。token-bucket 0 slots 时立即 raise `SchwabRateLimitError`，
让 agent 自己 backoff。这是为了避免阻塞别的并发 tool。详见
[`troubleshooting/rate-limit-token-bucket-empty.md`](troubleshooting/rate-limit-token-bucket-empty.md)。

### 15. 我能调高 `SCHWAB_RATE_LIMIT_PER_MIN` 吗？

**不要超过 120**。Schwab 服务端会先发飙，把账户级配额封掉。

### 16. 多个 agent 共用同一 server 会怎样？

token-bucket 是 server **进程级**共享。多 agent 加起来才是 120/min。
详见
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md)。

## 调用 / 业务

### 17. symbol 必须 UPPERCASE 吗？

是。`"aapl"` 立即被 Pydantic 拒。详见
[`troubleshooting/validation-symbol.md`](troubleshooting/validation-symbol.md)。

### 18. 怎么查指数？

加 `$` 前缀：`get_quote("$SPX")` / `get_quote("$DJI")`。详见
[`tools/tool-reference-quotes.md`](tools/tool-reference-quotes.md)。

### 19. OSI option symbol 格式？

21 字符固定：`{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}`。详见
[`concepts/osi-option-symbol.md`](concepts/osi-option-symbol.md)。

### 20. `get_price_history` 报 cartesian product 错误？

`(period_type, period, frequency_type, frequency)` 四元组只接受受限
组合。详见
[`troubleshooting/validation-pricehistory-cartesian.md`](troubleshooting/validation-pricehistory-cartesian.md)。

### 21. `get_quotes` 一次最多多少 symbol？

50。超过自行分批。详见
[`troubleshooting/validation-batch-50.md`](troubleshooting/validation-batch-50.md)。

### 22. 错误为什么不抛异常？

server 把所有 schwab-py 异常包装成 `{"error": "..."}` dict 返回，让
agent 拿到结构化数据而非语言相关的异常。详见
[`error-recovery.md`](error-recovery.md)。

## 安全

### 23. .env 不小心 commit 了怎么办？

**第一步**：去 Developer Portal **Reset App Secret**（这才真正切断
攻击者）。然后走
[`credentials-rotate-runbook.md`](credentials-rotate-runbook.md) 的
分支审查流程。**不要** force-push 主分支。

### 24. token.json 落在 iCloud / Dropbox 同步盘怎么办？

server 默认拒绝（`SchwabAuthError(reason="cloud_path_detected")`）。改
`--config-dir` 到非同步路径，或用
`--i-understand-cloud-sync-risk` 显式 override（不推荐）。详见
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md)。

### 25. 凭证如何保密？

`.env` 仅本地 + `chmod 600`；`token.json` 在 allow-list 路径下 +
`chmod 600`；pre-commit 钩子（gitleaks + detect-secrets）拦
secret commit。详见
[`quick-start/step-2-credentials-env.md`](quick-start/step-2-credentials-env.md)。

## skill / agent

### 26. skill 与 MCP server 是什么关系？

skill 是**文档**（描述如何用 server）；server 是**进程**（实际跑 tool
call）。两者通过 MCP 协议通信。skill 在 frontmatter 里声明
`compatible_mcp_version` 范围，激活时 agent 调 `get_server_info` 校验。

### 27. 为什么必须先调 `get_server_info` 再调 `health_check`？

这是 **Activation handshake**。`get_server_info` 校验版本兼容；
`health_check` 校验 token 真的可用。任何一项不通过都立即停下，
不要静默 fallback。详见
[`concepts/key-concepts.md`](concepts/key-concepts.md)。

### 28. ops vs workflows 两个 skill 怎么选？

ops 是**单 tool call** + troubleshooting；workflows 是**多步 playbook**
（写 markdown 到私有仓）。详见 README。

### 29. agent 必须用简体中文回复吗？

是。两个 skill 的 `language_directive` 字段都强制 Simplified Chinese。

### 30. 客户端兼容性？

Cursor / Claude Code / Kiro CLI / Cline / Roo Code 等 skills-compatible
agents。详见 README 与
[`compatibility-matrix.md`](#) 与 ops/SKILL.md 的 Compatibility 表格。

## 故障与恢复

### 31. 调任何 tool 都返回 SchwabAuthError 怎么办？

跑 `auth login_flow` 重新 OAuth。详见
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md)。

### 32. 怎么提 issue / 报 bug？

带上 server.log 末 100 行（**先脱敏 Bearer / token / App Key**）+ 调用
args + 期望 vs 实际行为。在 `schwab-marketdata-mcp` 仓库 issue tracker
提。

### 33. 我可以 fork 来改吗？

可以，但必须保留 ToS 通知 + 凭证保护逻辑（`.env` allow-list、token 路径
allow-list、cloud-sync 检测、pre-commit 钩子）—— 这些是法律 / 安全级别
的 contract。

### 34. 哪里看 server 内部源码？

`schwab-marketdata-mcp` 仓库 `src/schwab_marketdata_mcp/`。架构图见
[`concepts/architecture-overview.md`](concepts/architecture-overview.md)。

### 35. 想要 Trader API（下单）功能怎么办？

本 server **不支持**且**不会**支持 Trader API（设计上是 read-only
market data only）。如需下单，自己实现一个独立的 server 并仔细评估
法律 / 资质 / 安全风险。

## 参考

- 完整 reference 索引：见 ops/SKILL.md `## Reference index` 段
- Quick Start 7 步：[`quick-start/`](quick-start/)
- 错误体系：[`error-recovery.md`](error-recovery.md)
