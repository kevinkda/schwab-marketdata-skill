# Quick Start — Step 3: Run your first OAuth flow

> **目标**：完成 Schwab 3-legged OAuth 一次端到端 dance，把 `token.json`
> 落地到 `~/.local/state/schwab-marketdata-mcp/`。

## 前置条件

- [ ] 已完成 [Step 2](step-2-credentials-env.md)，`.env` 三字段已填
- [ ] 浏览器能访问 <https://127.0.0.1:8182>（`login_flow`）或可手动复制
      callback URL（`manual_flow`）

## 选哪个 mode

| 场景 | 推荐 |
| ---- | ---- |
| 普通笔记本 / 本地能开 https 监听 8182 | `login_flow`（默认） |
| SSH-only / 远程容器 / WSL2 / 浏览器无法访问 `127.0.0.1` | `manual_flow` |
| Cron / 自动化无人值守 | **不支持** — Schwab OAuth 必须人参与一次 |

详细决策树见 [`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)。

## A. `login_flow`（默认）

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth login_flow
```

行为：

1. CLI 在本地起一个 https 监听（端口 `8182`，自签证书）。
2. 自动打开浏览器到 Schwab 登录页。
3. 你在浏览器登录 → Allow → Schwab 重定向到 `https://127.0.0.1:8182/...`。
4. 浏览器一次性弹 **ERR_SSL_PROTOCOL_ERROR / Self-signed cert** 警告：
   点 **Advanced → Proceed**（这是 schwab-py 自动生成的本地证书，
   合法）。
5. CLI 拿到 callback URL → 用 App Secret 换出 access_token + refresh_token
   → 写到 `~/.local/state/schwab-marketdata-mcp/token.json`（`chmod 600`）。

## B. `manual_flow`（headless）

```bash
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

行为：

1. CLI 把一条 OAuth URL **打印到 stdout**（形如
   `https://api.schwabapi.com/v1/oauth/authorize?...`）。
2. 你**复制**这条 URL，粘到任意能上 Schwab 的浏览器，登录 → Allow。
3. Schwab 把你重定向到 `https://127.0.0.1/?code=...&state=...` —
   浏览器会显示 `Connection refused` —— **这是预期的**。
4. 从地址栏**完整复制** redirect URL（含 `?code=...` 整段），粘回 CLI。
5. CLI 用这条 URL 完成 token exchange。

## 期望产出

- `~/.local/state/schwab-marketdata-mcp/token.json` 已存在
- 权限 = `600`，父目录权限 = `700`
- 文件内容是合法 JSON，含 `access_token` / `refresh_token` / 元数据字段

## 验证清单

- [ ] `ls -l ~/.local/state/schwab-marketdata-mcp/token.json`
      → `-rw------- ... token.json`
- [ ] `cat ~/.local/state/schwab-marketdata-mcp/token.json | python -m json.tool`
      退出码 = 0
- [ ] `stat -c '%a' ~/.local/state/schwab-marketdata-mcp` = `700`
      （macOS：`stat -f '%A'`）
- [ ] CLI stdout 含 `Token persisted to ...token.json`
      （schwab-py 1.5+ 的标准日志）

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| 浏览器 `ERR_SSL_PROTOCOL_ERROR` | 点 Advanced → Proceed；自签证书是预期的 |
| `MismatchingStateException ("CSRF Warning!")` | `.env` 的 `SCHWAB_CALLBACK_URL` 与 Portal 注册值不一致；改回去；详见 [`../oauth/oauth-callback-mismatch.md`](../oauth/oauth-callback-mismatch.md) 与 [`../troubleshooting/auth-callback-url-mismatch.md`](../troubleshooting/auth-callback-url-mismatch.md) |
| 端口 8182 被占用 | `lsof -i :8182` 找进程；停掉或换端口（同时改 Portal 注册值） |
| `manual_flow` 时 callback URL 没有 `?code=...` | Schwab 拒绝授权；多半是 App 没真正激活 Market Data Production product，回 [Step 1](step-1-developer-portal-app.md) 检查 |
| token 落到 iCloud / Dropbox 同步盘 | `SchwabAuthError(reason="cloud_path_detected")`；用 `--config-dir ~/.local/state/schwab-marketdata-mcp` 显式指定，或 `--i-understand-cloud-sync-risk` 兜底 |

## 不要做的事

- **不要** 把 `token.json` 内容贴到任何聊天 / issue / PR 中。
- **不要** 复制 token.json 到另一台机器（refresh_token 与 IP 绑定 +
  rotate-on-use 会立即让旧机器版本失效）。

## 下一步

→ [Step 4: Verify token is healthy](step-4-token-health-check.md)

## 参考

- 完整 OAuth 流程图：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
- `login_flow` 详解：[`../oauth/oauth-login-flow.md`](../oauth/oauth-login-flow.md)
- `manual_flow` 详解：[`../oauth/oauth-manual-flow.md`](../oauth/oauth-manual-flow.md)
- 自部署 callback 服务：[`../oauth/oauth-self-host-callback.md`](../oauth/oauth-self-host-callback.md)
