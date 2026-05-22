# Error recovery — index

MCP server 把所有 Schwab 失败规范化为结构化 dict（`error` 字段非 None），**不抛异常**穿透 MCP 协议。本文件只做**分流索引**，具体处置分散在 3 个 troubleshooting 子文件里。

---

## 路由表 — 按 `error` 类型分流

| `error` | 子文件 | 含义 |
| ------- | ------ | ---- |
| `SchwabAuthError` | [`troubleshooting-auth.md`](troubleshooting-auth.md) | OAuth / token / 凭证类故障（6 个 reason） |
| `SchwabRateLimitError` | [`troubleshooting-rate-limit.md`](troubleshooting-rate-limit.md) | 限流类故障（429、token-bucket 0 slots、Retry-After 缺失） |
| `SchwabValidationError` | [`troubleshooting-validation.md`](troubleshooting-validation.md) | Pydantic 输入验证拒绝（symbol 正则、笛卡尔积、>50 symbol、OSI 格式） |
| `SchwabTransientError` | （本文 §1） | Schwab 5xx / 网络抖动；server 已重试 `SCHWAB_MAX_RETRIES` 次 |

---

## §1. `SchwabTransientError`（本文兜底）

- **Symptom**：`{"error":"SchwabTransientError","status_code":<5xx 或 4xx 非 401/429>,"message":…}`。
- **Root cause**：
  - 5xx：Schwab 服务端故障 / 网关超时；schwab-py 已按 `SCHWAB_MAX_RETRIES`（默认 2）次指数退避重试仍失败。
  - 非 401/429 的 4xx：通常是 Pydantic 没拦下来的边角输入问题（如某个字段 Schwab 服务端比文档更严格）。
- **修复策略**：
  - 5xx：等几分钟后重试；如果 30 分钟内 ≥ 3 次同类错误 → 告诉用户 Schwab 那边有故障，
    建议查 [Schwab Developer Portal Status](https://developer.schwab.com/) 公告。
  - 4xx：对照 `troubleshooting-validation.md` 与 `tool-reference.md` 检查参数；若仍无解 → 在 schwab-marketdata-mcp 仓库提 issue。
- **验证**：连续 3 次重试有至少 1 次成功 = 临时抖动；持续失败 = 真故障。

---

## Decision flow for the agent

1. **永远先查 `error` 字段**再向用户呈现结果。如果非空，按上述路由表跳到对应子文件，**不要把 raw stack trace 显示给用户**。
2. 对 `SchwabAuthError(reason ∈ {refresh_token_expired, token_not_initialized, callback_url_mismatch})` ——
   **agent 必须停下让用户走 `auth login_flow`**，不要静默重试。
3. 对 `SchwabRateLimitError` —— 可在 `retry_after_seconds` 后重试一次；连续两次失败 → 告诉用户。
4. 对 `SchwabValidationError` —— agent **修正输入后重试一次**（`aapl` → `AAPL`、把 60 个 symbol 拆成 50 + 10）；修正后仍失败才打扰用户。

---

## 不要做的事

- **不要** echo 任何 `Bearer …` header 到用户可见的输出。MCP server 已在全局过滤里做了脱敏，但 agent 也要做最后一道兜底 mask。
- **不要** 在 `SchwabAuthError` 上静默重试。
- **不要** 凭证泄露后用 `git push --force` 抹历史；走 [`credentials-rotate-runbook.md`](credentials-rotate-runbook.md) 的安全分支 + PR 审查流程。
