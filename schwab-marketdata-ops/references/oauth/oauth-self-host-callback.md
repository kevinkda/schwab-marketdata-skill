# OAuth — Self-host the callback endpoint

> **进阶**：用自己的 https 反代或公网 endpoint 接住 OAuth callback，
> 完全不依赖 schwab-py 的本地 8182 监听。**不推荐**作为日常方案 ——
> 多一道公网 hop 就多一道泄露面。仅当 `login_flow` 与 `manual_flow`
> 都不可行时考虑。

## 适用场景

- 本机彻底没浏览器 + 任何浏览器都无法粘 redirect URL（极罕见）
- 团队共享一个 OAuth app，希望 callback 落到团队拥有的 https endpoint
  做集中审计（**注意**：Market Data 是 non-redistributable，团队共享
  本身就违反 ToS，本节仅做技术说明）
- 内网环境，loopback https 监听被安全策略禁用，又有可控的内网 https
  endpoint

## 强制前提

1. 必须是 **https**（Schwab 不接受 http callback）。
2. Endpoint 必须在 Developer Portal 中**字符级一致**地注册为 callback
   URL（含 trailing slash 与否）。
3. 你能拿到 callback 收到的完整 redirect URL（含 `?code=...&state=...`）。
4. 能在 5 分钟内把 redirect URL 喂回 schwab-py CLI 完成 token 交换
   （OAuth code 5 分钟过期）。

## 推荐架构

```
┌───────────────────┐    1. browser opens authorize URL
│  你（在任意机器） │ ────────────────────────────────────────────▶ Schwab OAuth
└───────────────────┘
         ▲                                                              │
         │ 4. 复制 redirect URL，粘到目标机器的 manual_flow CLI            │
         │                                                              ▼
         │                                          ┌───────────────────────┐
         │      3. 落地到日志 / 共享 secret store    │ 你的 https endpoint   │
         │  ◀────────────────────────────────────── │ (e.g. nginx + lua)    │
         │                                          └───────────────────────┘
         │                                                      ▲
         │                                                      │ 2. Schwab redirect
         │                                                      │    ?code=...&state=...
         ▼                                                      │
┌───────────────────┐
│  目标机器        │
│  manual_flow CLI │
└───────────────────┘
```

## 实现要点

### 1. nginx + lua 简化方案

```nginx
server {
    listen 443 ssl http2;
    server_name oauth.example.com;

    ssl_certificate     /etc/letsencrypt/live/oauth.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/oauth.example.com/privkey.pem;

    location /schwab/callback {
        # 把整个 query string 写入受保护的日志（仅 root 可读）
        access_log /var/log/nginx/schwab-oauth.log redirect_url_with_query;
        # 返回一段静态 HTML，提示用户复制地址栏
        default_type text/html;
        return 200 '<!doctype html><html><body><h1>OAuth callback received</h1>
            <p>Copy the full URL from the address bar and paste into your manual_flow CLI.</p>
            </body></html>';
    }
}

log_format redirect_url_with_query '$time_iso8601 $remote_addr $request_uri';
```

`/var/log/nginx/schwab-oauth.log` 必须 `chmod 600` 仅 root 读，且 5
分钟后立即轮转 / 删除（OAuth code 过期时会失效，但 `state` 用作 CSRF
防护，仍属敏感）。

### 2. 走完 OAuth 后，使用 `manual_flow`

```bash
# Step A: 在浏览器打开 schwab-py 提供的 authorize URL
uv run python -m schwab_marketdata_mcp.auth manual_flow

# Step B: 浏览器跳到 https://oauth.example.com/schwab/callback?code=...
# Step C: 从浏览器地址栏 OR 服务器日志拿到完整 redirect URL
# Step D: 粘回 CLI stdin
```

或者你的 callback endpoint 直接把完整 URL **echo 到 HTML 页面**，让
用户从页面复制（避免 SSH 上 cat 日志的麻烦）。

## 安全建议

- callback endpoint 上**不要**自动调 token endpoint（即不要替代 schwab-py
  完成第二腿）—— 那意味着 App Secret 必须放到 endpoint 上，扩大泄露面。
  让 schwab-py CLI 在你信任的机器上完成 token 交换。
- callback endpoint 必须仅记录 `?code=` 与 `?state=` 两个参数，不要把
  完整 query string 永久落盘到中央日志服务。
- 把 endpoint 加到防火墙白名单：仅允许 Schwab 出口 IP 段访问（Schwab 不
  公布稳定 IP，可放宽到全美东数据中心 ASN）。
- TLS 必须是有效证书（Let's Encrypt / 商业 CA），不要自签 —— Schwab 在
  redirect 时不会验证证书但浏览器会，影响用户体验。

## 不要做的事

- **不要** 用 ngrok / Cloudflare Tunnel 等隧道作为长期 callback endpoint
  —— URL 漂移会让 Portal 注册值频繁失效。
- **不要** 把 callback URL 注册成 `http://` —— Schwab 拒。
- **不要** 把 OAuth code 转发到第三方 webhook —— code 是凭证，自己留着
  完成 token exchange。

## 何时回退到 `login_flow` / `manual_flow`

绝大多数情况下 `manual_flow` 已经足够：你只需要**任意一台**能访问
Schwab + 你能复制粘贴 URL。如果连这都做不到，先解决浏览器与剪贴板的
问题，比维护一个公网 https endpoint 简单得多。

## 参考

- 端到端 OAuth：[`oauth-overview.md`](oauth-overview.md)
- 默认方案 `login_flow`：[`oauth-login-flow.md`](oauth-login-flow.md)
- Headless 方案 `manual_flow`：[`oauth-manual-flow.md`](oauth-manual-flow.md)
- ToS 关于不可再分发：[`../tos-snapshot.md`](../tos-snapshot.md)
