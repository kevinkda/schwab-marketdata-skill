# Troubleshooting — `SchwabAuthError(reason="refresh_token_expired")`

**已经过期**，必须人介入走一次完整 OAuth flow。**不能**通过任何 token
roll / refresh 尝试挽救。

## Symptom

- 业务 tool 调用返回 `{"error":"SchwabAuthError","reason":"refresh_token_expired"}`
- schwab-py 内部刷新失败抛 `OAuth2Error: invalid_grant`
- `health_check()` 此时 token_state **仍可能** == `"valid"`（因为本地
  文件没动），但任何业务 call 都失败

## Root cause

refresh_token 7 天**绝对**寿命已到期，服务端 invalidate，**不可挽救**。
这是 Schwab OAuth 的硬限制。

## 检查命令

```bash
uv run python -m schwab_marketdata_mcp.health
# token_state == "valid" 但 token_expires_in_days <= 0
```

## 修复命令

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# 远程 / SSH-only：
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## 验证命令

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# 然后用一个最小 MCP client 调一次 get_quote("VOO") 确认 200 OK
# （详见 quick-start/step-5-first-mcp-tool-call.md）
```

## 常见混淆

| 混淆                                        | 真相                                                       |
| ------------------------------------------- | ---------------------------------------------------------- |
| "我刚刚才 refresh，不应该过期啊"            | refresh 不延长 7 天总寿命，只 rotate 出新的 RT             |
| "我能不能用旧 token.json 备份 rollback？"     | 不能。rotate-on-use 让旧 RT 立即失效                       |
| "能否绕过 7 天限制？"                        | 不能。这是 Schwab OAuth 设计，server 端硬约束               |
| "重启 server 能修复？"                       | 不能。server 重启不影响 server-side token 状态             |

## agent 行为约束

- agent **必须停下**让用户走 `auth login_flow`，**不要**静默重试。
- agent 应在 stdout / chat 里告诉用户具体命令（`uv run python -m
  schwab_marketdata_mcp.auth login_flow`），方便 copy-paste。
- agent **不要**主动 delete token.json —— 用户 reauthorize 后 schwab-py
  会自动覆盖。

## 不要做的事

- **不要** 在 cron 里跑 `login_flow`（OAuth 需要人参与）。
- **不要** 把这个错误当成 transient 错误重试。
- **不要** 把它当成 callback URL mismatch（那个 reason 不一样）。

## 参考

- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- 提前预警处置：[`auth-refresh-expiring-soon.md`](auth-refresh-expiring-soon.md)
- OAuth login_flow：[`../oauth/oauth-login-flow.md`](../oauth/oauth-login-flow.md)
- OAuth manual_flow：[`../oauth/oauth-manual-flow.md`](../oauth/oauth-manual-flow.md)
