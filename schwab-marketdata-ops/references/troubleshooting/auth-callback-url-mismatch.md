# Troubleshooting — `SchwabAuthError(reason="callback_url_mismatch")`

`.env` 里的 `SCHWAB_CALLBACK_URL` 与 Schwab Developer Portal 上注册的
Callback URL 不一致。OAuth 在 callback 阶段**字符级匹配**，差一个字符
都失败。

## Symptom

- `auth login_flow` 启动浏览器后，OAuth redirect 阶段报
  `MismatchingStateException ("CSRF Warning!")`
- server 启动时直接 raise 此错误（启动期校验）
- 业务 call 不会触发这个 reason —— 它在 OAuth 第一次走时就暴露

## Root cause

`.env` 的 `SCHWAB_CALLBACK_URL` 与 [Developer Portal](https://developer.schwab.com/dashboard/apps)
注册值**不完全相等**。差一个字符（trailing slash、http vs https、
端口号、子域名、大小写）都算不一致。

## 检查命令

```bash
grep -E '^SCHWAB_CALLBACK_URL=' /path/to/schwab-marketdata-mcp/.env
# 然后到 https://developer.schwab.com/dashboard/apps 看注册值
```

或者用 dry-run 提前验证：

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
# 输出 "Callback URL: ..."；与 Portal 值字符级 diff
```

## 修复命令

编辑 `.env`，把 `SCHWAB_CALLBACK_URL` 改成与 Developer Portal **逐字符
相同**：

```bash
# 编辑 .env 后重启 server
pkill -f schwab_marketdata_mcp || true
```

如果你已经走过几次失败的 OAuth：

```bash
# 没必要 rm token.json —— 既然 OAuth 没成功过，本来就没 token
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 验证命令

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
# 浏览器走完一圈不再报 callback mismatch
uv run python -m schwab_marketdata_mcp.health   # exit 0
```

## 9 种常见的不一致形态

详见 [`../oauth/oauth-callback-mismatch.md`](../oauth/oauth-callback-mismatch.md)，
摘录前 5 种最常见：

| `.env` 中                            | Portal 中                              |
| ------------------------------------ | -------------------------------------- |
| `https://127.0.0.1:8182`             | `https://127.0.0.1:8182/`              |
| `http://127.0.0.1:8182`              | `https://127.0.0.1:8182`               |
| `https://localhost:8182`             | `https://127.0.0.1:8182`               |
| `https://127.0.0.1:8182/callback`    | `https://127.0.0.1:8182`               |
| 末尾隐藏 CR / LF                     | （没有）                                |

## 不要做的事

- **不要** 用 wildcard 注册（Schwab 不支持）。
- **不要** 在 `.env` 里给 callback URL 加引号（shell 解析后字符就不一
  样了）。
- **不要** 反复试 OAuth 而不查 `.env` 与 Portal 的 diff —— OAuth code 5
  分钟过期，反复试只会浪费时间。

## 参考

- callback URL 不一致深度：[`../oauth/oauth-callback-mismatch.md`](../oauth/oauth-callback-mismatch.md)
- OAuth login_flow：[`../oauth/oauth-login-flow.md`](../oauth/oauth-login-flow.md)
- OAuth manual_flow：[`../oauth/oauth-manual-flow.md`](../oauth/oauth-manual-flow.md)
