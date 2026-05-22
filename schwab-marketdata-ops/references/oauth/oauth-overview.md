# OAuth — overview

> Schwab Market Data Production 用 **3-legged OAuth 2.0**，由
> `schwab-py` 处理 token 交换。本文给出端到端流程图与 mode 决策树，
> 子文件深入每种 mode 的细节。

## 流程图

```text
┌──────────────┐  1. open browser/print URL  ┌───────────────────┐
│  你（人）    │ ──────────────────────────▶ │ Schwab OAuth UI   │
│              │                              │ (login + Allow)   │
│              │  2. redirect ?code=...       │                   │
│              │ ◀──────────────────────────  │                   │
└──────────────┘                              └───────────────────┘
       │                                              │
       │ 3. CLI 收 code                                │
       ▼                                              │
┌──────────────────────┐  4. token exchange (POST)    │
│ schwab-py CLI        │ ──────────────────────────▶ Schwab token endpoint
│ (login_flow /        │                              │
│  manual_flow)        │  5. {access_token,           │
│                      │      refresh_token, ...}    │
│                      │ ◀──────────────────────────  │
│ 6. write             │
│    token.json        │
│    chmod 600         │
└──────────────────────┘
```

## Mode 决策树

| 场景                                              | 推荐 mode             | 详细文档                                              |
| ------------------------------------------------- | --------------------- | ----------------------------------------------------- |
| 普通笔记本 + 本地能起 https 监听 :8182             | `login_flow`（默认）   | [`oauth-login-flow.md`](oauth-login-flow.md)         |
| SSH-only / Docker / WSL2 / 浏览器无法访问 127.0.0.1 | `manual_flow`         | [`oauth-manual-flow.md`](oauth-manual-flow.md)       |
| 想完全不依赖 schwab-py 的 callback 监听            | self-host callback     | [`oauth-self-host-callback.md`](oauth-self-host-callback.md) |
| Cron / 自动化无人值守                              | **不支持**             | Schwab OAuth 必须人参与一次                           |
| 多账户 / 多机器                                    | 每账户 / 每机器单独走一次 OAuth | 不要复制 `token.json`（refresh_token 与机器绑定 + rotate-on-use） |

## 三种 mode 的通用 CLI 入口

```bash
# Default: login_flow
uv run python -m schwab_marketdata_mcp.auth login_flow

# Headless / remote
uv run python -m schwab_marketdata_mcp.auth manual_flow

# 自定义 token 路径（必须落在 allow-list 子目录）
uv run python -m schwab_marketdata_mcp.auth login_flow --config-dir ~/.config/schwab

# Override cloud-sync safety（仅在你确实知道后果时使用）
uv run python -m schwab_marketdata_mcp.auth login_flow --i-understand-cloud-sync-risk

# Dry-run（不打开浏览器，只打印将使用的 callback URL，便于排查）
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
```

## Token 三要素

| 要素             | 寿命                | 自动刷新？               |
| ---------------- | ------------------- | ------------------------ |
| `access_token`   | 90 分钟              | ✅ schwab-py 在每次 API call 前自动检查、自动刷新 |
| `refresh_token`  | **7 天绝对寿命**     | ❌ 7 天后必须重新走 OAuth（不可绕过 —— Schwab 设计如此） |
| OAuth `code`     | 一次性，5 分钟       | ❌ 走完 OAuth 即作废       |

**rotate-on-use**：每次刷新都签发**新的 refresh_token** 替换旧的。这意味
着：

1. 你**不能**复制 `token.json` 到另一台机器同时使用（先到的会让晚到的
   失效）。
2. 备份 `token.json` 之后**不能**回退到那个备份（refresh_token 已被
   rotate）。
3. 多机器同账户必须走多次 OAuth。

详见 [`oauth-token-lifecycle.md`](oauth-token-lifecycle.md)。

## Token 落地路径

默认：`${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/token.json`
（Linux 与 macOS 一致 —— 我们刻意不用 macOS 的
`~/Library/Application Support`，便于跨机迁移与自动备份脚本统一）。

权限：

- `token.json`：`chmod 600`
- 父目录：`chmod 700`

权限漂移时 server 拒绝启动并打印 `chmod 600 ...` hint。

## 验证 token 真正可用

```bash
# 推荐：built-in health 模块
uv run python -m schwab_marketdata_mcp.health
# 期望：exit 0；stdout 含 "token_state": "valid"
```

或用一个最小 MCP client（见 [Quick Start Step 5](../quick-start/step-5-first-mcp-tool-call.md)）跑一次
`get_quote("VOO")`。

## 不要做的事

- **不要** 在 cron 里直接跑 `auth login_flow` —— OAuth 必须人参与。
- **不要** 复制 `token.json` 到云同步盘（iCloud / Dropbox / OneDrive）。
- **不要** echo `Bearer ...` header 到任何用户可见输出（即使错误信息
  里出现，先 mask）。
- **不要** 在 7 天到期前继续等 —— `health` 已在 < 12h 时主动提醒。

## 参考

- `login_flow` 详解：[`oauth-login-flow.md`](oauth-login-flow.md)
- `manual_flow` 详解：[`oauth-manual-flow.md`](oauth-manual-flow.md)
- 自部署 callback：[`oauth-self-host-callback.md`](oauth-self-host-callback.md)
- token 生命周期：[`oauth-token-lifecycle.md`](oauth-token-lifecycle.md)
- callback URL 不一致排查：[`oauth-callback-mismatch.md`](oauth-callback-mismatch.md)
- TokenState 4 状态：[`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
