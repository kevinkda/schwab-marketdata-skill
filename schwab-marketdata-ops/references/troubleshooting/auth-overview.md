# Troubleshooting — overview

> 路由表：按你看到的 `error` 字段值跳到对应子文件。

## 路由表 — 按 `error` 类型分流

| `error` 字段值              | 子文件                                                              | 含义                                            |
| --------------------------- | ------------------------------------------------------------------- | ----------------------------------------------- |
| `SchwabAuthError`           | [`auth-overview.md`](auth-overview.md)                              | OAuth / token / 凭证类故障（6 个 reason）        |
| `SchwabRateLimitError`      | [`rate-limit-overview.md`](rate-limit-overview.md)                  | 限流类故障（429、token-bucket 0 slots、Retry-After 缺失） |
| `SchwabValidationError`     | [`validation-overview.md`](validation-overview.md)                  | Pydantic 输入验证拒绝                            |
| `SchwabTransientError`      | [`transient-errors.md`](transient-errors.md)                        | Schwab 5xx / 网络抖动                           |

## 路由表 — 按症状描述分流

| 症状                                                  | 跳转                                                                       |
| ----------------------------------------------------- | -------------------------------------------------------------------------- |
| `health_check` 返回 `token_state != "valid"`         | [`auth-token-states.md`](auth-token-states.md)                            |
| `SchwabAuthError(reason="refresh_token_expired_soon")` | [`auth-refresh-expiring-soon.md`](auth-refresh-expiring-soon.md)        |
| `SchwabAuthError(reason="refresh_token_expired")`    | [`auth-refresh-expired.md`](auth-refresh-expired.md)                      |
| `SchwabAuthError(reason="token_not_initialized")`    | [`auth-token-not-initialized.md`](auth-token-not-initialized.md)         |
| `SchwabAuthError(reason="token_corrupted")`           | [`auth-token-corrupted.md`](auth-token-corrupted.md)                      |
| `SchwabAuthError(reason="insecure_token_perms")`     | [`auth-insecure-perms.md`](auth-insecure-perms.md)                        |
| `SchwabAuthError(reason="callback_url_mismatch")`    | [`auth-callback-url-mismatch.md`](auth-callback-url-mismatch.md)         |
| Schwab 返回 429                                       | [`rate-limit-429.md`](rate-limit-429.md)                                  |
| token-bucket 0 slots 立即 raise                       | [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)   |
| stderr `rate_limit_warning` 但调用成功                | [`rate-limit-warning-stderr.md`](rate-limit-warning-stderr.md)            |
| 429 但缺 `Retry-After` 头                             | [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)            |
| symbol 正则不匹配                                     | [`validation-symbol.md`](validation-symbol.md)                            |
| price history 笛卡尔积非法                            | [`validation-pricehistory-cartesian.md`](validation-pricehistory-cartesian.md) |
| `get_quotes` 超 50                                   | [`validation-batch-50.md`](validation-batch-50.md)                        |
| OSI 格式错                                            | [`validation-osi-format.md`](validation-osi-format.md)                    |
| Schwab 5xx                                            | [`transient-errors.md`](transient-errors.md)                              |

## Decision flow

1. **永远先查 `error` 字段**再向用户呈现结果。如果非空，按上述路由表
   跳到对应子文件，**不要**把 raw stack trace 显示给用户。
2. 对 `SchwabAuthError(reason ∈ {refresh_token_expired,
   token_not_initialized, callback_url_mismatch})` —— **agent 必须停下让
   用户走 `auth login_flow`**，不要静默重试。
3. 对 `SchwabRateLimitError` —— 可在 `retry_after_seconds` 后重试一次；
   连续两次失败 → 告诉用户。
4. 对 `SchwabValidationError` —— agent **修正输入后重试一次**（`aapl`
   → `AAPL`、把 60 个 symbol 拆成 50 + 10）；修正后仍失败才打扰用户。
5. 对 `SchwabTransientError` —— 等几分钟重试；30 分钟内 ≥ 3 次同类错误
   → 告诉用户 Schwab 那边可能有故障。

## 不要做的事

- **不要** echo 任何 `Bearer ...` header 到用户可见的输出。MCP server
  已在全局过滤里做了脱敏，但 agent 也要做最后一道兜底 mask。
- **不要** 在 `SchwabAuthError` 上静默重试。
- **不要** 凭证泄露后用 `git push --force` 抹历史；走
  [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md) 的
  安全分支 + PR 审查流程。

## 参考

- 错误体系总览：[`../error-recovery.md`](../error-recovery.md)
- 凭证轮换 runbook：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- 健康巡检自动化：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
