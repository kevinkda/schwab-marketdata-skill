# OAuth — `manual_flow` (headless / SSH-only)

> 推荐给 SSH 远程机 / 容器 / WSL2 / 浏览器无法访问 `127.0.0.1` 的环境。

## 工作原理

1. CLI 把一条 OAuth 授权 URL **打印到 stdout**（形如
   `https://api.schwabapi.com/v1/oauth/authorize?...`）。
2. 你**复制**这条 URL，粘到任意能访问 Schwab 的浏览器（笔记本、手机、
   宿主机），登录 → Allow。
3. Schwab 把你重定向到 `https://127.0.0.1/?code=...&state=...`。浏览器
   会显示 `Connection refused` 或 `Site can't be reached` —— **这是预期
   行为**（`127.0.0.1` 那边没人监听）。
4. 从浏览器**地址栏**完整复制 redirect URL（包含 `?code=...&state=...`
   整段），粘回 CLI 的 stdin。
5. CLI 解析 `code` → 调 token endpoint 交换 → 写 `token.json`。

## CLI

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## 必备前置

- `.env` 里 `SCHWAB_CALLBACK_URL=https://127.0.0.1`（**注意没有端口**；
  与 Developer Portal 注册值字符级一致）
- 任意一台能访问 <https://api.schwabapi.com> 的浏览器（不一定是当前
  机器；手机也行）
- SSH session 不会因为 `manual_flow` 等待输入而超时（建议跑在 tmux /
  screen 里，避免断网丢失进度）

## 完整对话样例

```bash
$ uv run python -m schwab_marketdata_mcp.auth manual_flow
[INFO] Manual OAuth flow.

Visit this URL in any browser, authorize the app, and paste the
redirect URL (the one your browser cannot load) below:

  https://api.schwabapi.com/v1/oauth/authorize?response_type=code&client_id=...&redirect_uri=https%3A%2F%2F127.0.0.1&state=...

Paste redirect URL: ▎
```

复制 stdout 上这条 URL → 在另一台浏览器登录 → Allow → 浏览器跳转到
`https://127.0.0.1/?code=ABC...&session=…&state=...`（出错页面）。

复制地址栏整段 → 粘回 CLI stdin → 回车。

```bash
Paste redirect URL: https://127.0.0.1/?code=ABC...&state=...
[INFO] Token persisted to /home/you/.local/state/schwab-marketdata-mcp/token.json
[INFO] Permissions chmod 600 enforced.
```

## 验证

```bash
ls -l ~/.local/state/schwab-marketdata-mcp/token.json
# 期望：-rw------- ... token.json
uv run python -m schwab_marketdata_mcp.health
# 期望：exit 0，"token_state": "valid"
```

## 何时**不要**用 `manual_flow`

| 场景                              | 改用                                            |
| --------------------------------- | ----------------------------------------------- |
| 普通笔记本，本地能开 8182          | [`oauth-login-flow.md`](oauth-login-flow.md)   |
| 想要完全自动化（无需人参与）       | **不可能** —— Schwab OAuth 设计如此              |

## 常见错误（`manual_flow` 特有）

| 现象                                                | 处置                                                              |
| --------------------------------------------------- | ----------------------------------------------------------------- |
| 浏览器跳到 `127.0.0.1` 后显示 `Connection refused` | **是预期行为**；从地址栏复制完整 URL                                |
| 复制粘贴丢了 `&state=...` 部分                      | 必须复制完整地址栏；丢字段会导致 CSRF 校验失败                      |
| 粘贴时多了个空格 / 换行                              | 多数 shell 会保留；必要时手工去掉                                  |
| `MismatchingStateException`                         | callback URL 与 Portal 不一致；详见 [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md) |
| code 在 5 分钟内未交换                               | OAuth code 一次性 + 短寿命；快速完成 paste 步骤                     |
| SSH session 中途断网                                  | 重新连接后从头跑 `manual_flow`（OAuth code 已作废）                |

## SSH 长会话保护建议

```bash
# 在 ssh 远程机上：
tmux new -s schwab-oauth
uv run python -m schwab_marketdata_mcp.auth manual_flow
# 如果本地 ssh 断线，重新连上后：
tmux attach -t schwab-oauth   # 接回去继续
```

## 不要做的事

- **不要** 在公共聊天 / issue 里粘 stdout 那条 OAuth URL —— 含
  `client_id` 与 `state`（虽然单次 5 分钟内无害，但泄露习惯不好）。
- **不要** 在 `code=...` 这一段交换之前关掉浏览器 tab —— OAuth code 是
  一次性的，关闭后必须重新跑 `manual_flow`。

## 参考

- 端到端 OAuth：[`oauth-overview.md`](oauth-overview.md)
- `login_flow`（默认）：[`oauth-login-flow.md`](oauth-login-flow.md)
- 自部署 callback：[`oauth-self-host-callback.md`](oauth-self-host-callback.md)
- callback URL 不一致排查：[`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
