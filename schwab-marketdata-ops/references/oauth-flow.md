# OAuth flow reference

Schwab API uses **3-legged OAuth** with a 90-minute access token and a
**7-day rotate-on-use refresh token**.  `schwab-py` handles the token
exchange; you (the agent) only need to know **which CLI mode** to tell
the user.

## Decision: `login_flow` vs `manual_flow`

| 场景                                            | 推荐 mode                                   |
| ----------------------------------------------- | ------------------------------------------- |
| 普通笔记本，本地能起 https 监听 (port 8182)     | `login_flow`（默认）                        |
| 远程开发 / SSH-only / containerized / WSL2      | `manual_flow`                               |
| 浏览器无法访问 `127.0.0.1`                      | `manual_flow`                               |
| 自动化/无人值守                                  | 不支持 — Schwab OAuth 必须人参与一次        |

## CLI invocations

```bash
# Default: login_flow (browser automatically opens; click through self-signed)
uv run python -m schwab_marketdata_mcp.auth login_flow

# Headless / remote: manual_flow (paste callback URL back manually)
uv run python -m schwab_marketdata_mcp.auth manual_flow

# Custom config dir (subject to allow-list — see security.py):
uv run python -m schwab_marketdata_mcp.auth login_flow --config-dir ~/.config/schwab

# Override cloud-sync safety (only if you really know what you're doing):
uv run python -m schwab_marketdata_mcp.auth login_flow --i-understand-cloud-sync-risk
```

## Verifying token works

OAuth 走完后用以下两步确认 token 真正可用：

**Step 1 — health 命令（推荐）**

```bash
uv run python -m schwab_marketdata_mcp.health
# 期望：
#   exit 0
#   stdout 含 "token_state": "valid", "token_expires_in_days": >=6.5
#   不在 ~/Desktop/SCHWAB_REAUTH_NEEDED.md 落地新文件
```

**Step 2 — 最小 MCP client snippet**（验证业务 call 也走得通）

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def verify():
    server_params = StdioServerParameters(
        command="uv",
        args=["run", "python", "-m", "schwab_marketdata_mcp"],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            health = await session.call_tool("health_check", {})
            assert health.content[0].text and '"valid"' in health.content[0].text, \
                f"token not valid: {health.content[0].text}"

            quote = await session.call_tool("get_quote", {"symbol": "VOO"})
            text = quote.content[0].text
            assert '"error"' not in text or '"error":null' in text, \
                f"get_quote failed: {text}"
            print("OK — token works, get_quote('VOO') returned a real quote.")


if __name__ == "__main__":
    asyncio.run(verify())
```

把以上保存为 `verify_token.py`，然后 `uv run python verify_token.py`。
看到 `OK — token works...` 即代表 token / OAuth / MCP 链路全通。

## Where the token lives

Default path: `${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/token.json`
(both Linux and macOS — we deliberately do **not** use
`~/Library/Application Support` to keep cross-machine migration trivial).

The file is `chmod 600`, parent dir is `chmod 700`.  If permissions
drift the server refuses to start with a `chmod 600 ...` hint.

## Token lifecycle

```
new token (login_flow)        ─────▶ 7 days ─────▶ refresh_token expires
                                       │
   first API call refreshes access     │
   token (90 min) automatically;       │
   refresh_token rotates each time.    │
                                       ▼
                       SchwabAuthError(reason="refresh_token_expired")
                                       │
                                       ▼
                       run login_flow again
```

The `health.py` cron runs **Sunday 20:00 + Wednesday 21:00 + every 4 h**
(see `docs/cron.example` in the MCP repo) and writes
`~/Desktop/SCHWAB_REAUTH_NEEDED.md` when expiry is <12 h.

## Common failures

| 现象                                                                | 原因 + 处置                                                                                     |
| ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 浏览器弹出后 "ERR_SSL_PROTOCOL_ERROR"                                | 自签证书 — 点 Advanced → Proceed.  schwab-py 内部生成证书，无需额外配置。                         |
| `SchwabAuthError(reason="callback_url_mismatch")`                    | `.env` 的 `SCHWAB_CALLBACK_URL` 必须**完全等于** Developer Portal 上注册的值。                  |
| `SchwabAuthError(reason="cloud_path_detected")`                      | token 落在 iCloud / Dropbox 等同步盘 — 改路径或 `--i-understand-cloud-sync-risk`。              |
| `SchwabAuthError(reason="path_not_in_allow_list")`                   | `--config-dir` 必须在 `~/.local/state` 或 `~/.config` 子目录里。                                |
| `SchwabAuthError(reason="insecure_token_perms")`                     | 按错误信息里的 `chmod 600 ...` / `chmod 700 ...` 修复后重启 server。                            |
