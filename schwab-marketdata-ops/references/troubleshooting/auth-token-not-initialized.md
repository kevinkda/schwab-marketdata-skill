# Troubleshooting — `SchwabAuthError(reason="token_not_initialized")`

**首次安装**或刚 `rm token.json` 后的状态。处置最简单：跑一次
`auth login_flow`。

## Symptom

- 首次启动 server 后立刻调任何 tool
- `health_check()` 返回 `token_state == "missing"`
- 业务 call 返回 `{"error":"SchwabAuthError","reason":"token_not_initialized"}`

## Root cause

默认 token 路径下没有 `token.json`，OAuth 从未走过 `login_flow`。

## 检查命令

```bash
ls -la "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/"
# 应看到 token.json；若不存在则未初始化
```

## 修复命令

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# 或：
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## 验证命令

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
ls -l "$TOKEN_PATH"
# 应看到 -rw------- (chmod 600)

uv run python -m schwab_marketdata_mcp.health   # exit 0
# 期望：token_state == "valid"
```

## 与 `token_corrupted` 的区别

| 维度                  | `token_not_initialized` | `token_corrupted`                            |
| --------------------- | ----------------------- | -------------------------------------------- |
| 文件存在？            | ❌                      | ✅                                           |
| `token_state`         | `missing`               | `malformed`                                  |
| 触发时机              | 首次安装 / `rm` 后      | JSON 损坏 / 字段缺失 / schwab-py 升级        |
| 修复                  | `auth login_flow`       | 备份 + 删 + `auth login_flow`                |

## 不要做的事

- **不要** 在 server 启动时直接静默 fallback 到 dummy token —— 必须立即
  raise，让用户知道要 OAuth。
- **不要** 把别人的 token.json 复制过来（rotate-on-use + 单机 binding）。

## 参考

- TokenState 4 种：[`auth-token-states.md`](auth-token-states.md)
- OAuth 初次：[`../quick-start/step-3-first-oauth.md`](../quick-start/step-3-first-oauth.md)
- 完整 OAuth：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
