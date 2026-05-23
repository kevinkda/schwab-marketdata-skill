# OAuth — `login_flow` (default)

> 推荐给**普通笔记本** / 本地能起 https 监听 8182 的环境。

## 工作原理

1. CLI 在本地起一个 https 监听（端口 `8182`，**自签证书**）。
2. 自动打开浏览器到 Schwab 登录页（用 OS 默认浏览器）。
3. 你在浏览器登录 → 点 Allow → Schwab 重定向到 `https://127.0.0.1:8182/...`。
4. 浏览器一次性弹 `ERR_SSL_PROTOCOL_ERROR` / `Self-signed cert`：点
   **Advanced → Proceed**（这是 schwab-py 自动生成的本地证书，是合法
   行为）。
5. CLI 拿到 callback URL → 用 App Secret 调 Schwab token endpoint
   交换 access_token + refresh_token → 写到 `token.json`（chmod 600）。

## CLI

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 必备前置

- `.env` 里 `SCHWAB_CALLBACK_URL=https://127.0.0.1:8182`（与 Developer
  Portal 注册值字符级一致）
- 端口 `8182` **空闲**；用 `lsof -i :8182` 检查
- 浏览器能访问 `https://127.0.0.1:8182`（部分企业网络代理会拦
  loopback https）
- 系统默认浏览器已设置（macOS：Settings → Desktop & Dock → Default
  web browser；Linux：`xdg-settings get default-web-browser`）

## 验证

```bash
ls -l ~/.local/state/schwab-marketdata-mcp/token.json
# 期望：-rw------- ... token.json
uv run python -m schwab_marketdata_mcp.health
# 期望：exit 0，"token_state": "valid"
```

## 何时**不要**用 `login_flow`

| 场景                              | 改用                                              |
| --------------------------------- | ------------------------------------------------- |
| SSH 进远程机                       | [`oauth-manual-flow.md`](oauth-manual-flow.md)   |
| 容器内（无 GUI 浏览器）            | [`oauth-manual-flow.md`](oauth-manual-flow.md)   |
| WSL2 + 浏览器在 Windows 端          | `manual_flow` 更简单（避免 WSL2 转发 8182 的麻烦）|
| 公司 VPN 拦 127.0.0.1               | `manual_flow` 或 [`oauth-self-host-callback.md`](oauth-self-host-callback.md) |
| 端口 8182 已被占用且不能释放       | 改 `.env` 的 `SCHWAB_CALLBACK_URL` 与 Portal 注册值同步换端口 |

## 常见错误（仅 `login_flow` 特有）

| 现象                                                         | 处置                                                                                |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| 浏览器弹 `ERR_SSL_PROTOCOL_ERROR`                            | 点 Advanced → Proceed；自签证书是预期的                                              |
| 浏览器卡在 `localhost refused to connect`                    | 端口被占用（`lsof -i :8182`）；或防火墙拦了 loopback                                  |
| `MismatchingStateException ("CSRF Warning!")`                | `.env` 与 Portal 注册的 callback URL 不一致；详见 [`oauth-callback-mismatch.md`](oauth-callback-mismatch.md) |
| 浏览器一直没自动打开                                          | OS 默认浏览器没设置；手工打开 stdout 上打印的 URL                                     |
| 跑完后 `token.json` 没出现                                    | OAuth 在 callback 阶段失败；翻 stderr 找 `Schwab*Error`                              |
| 端口 8182 偶尔会被 macOS Spotlight / Mail 等占用              | `stop <pid>`（or change port）；记得同步改 Portal 注册值                                       |

## 不要做的事

- **不要** 改 `--port` 之后忘记同步改 Portal 注册值 —— OAuth callback 阶段
  必然 CSRF fail。
- **不要** 把自签证书装到系统信任根（无意义；schwab-py 每次都重新生成）。
- **不要** 在浏览器里**保存** `127.0.0.1:8182` 的密码（无意义，且容易
  混淆）。

## 参考

- 端到端 OAuth 流程：[`oauth-overview.md`](oauth-overview.md)
- `manual_flow`（headless 替代）：[`oauth-manual-flow.md`](oauth-manual-flow.md)
- callback URL 不一致排查：[`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
