# Quick Start — Step 4: Verify token is healthy

> **目标**：用 `schwab_marketdata_mcp.health` 模块确认 token 真正可用，
> 并把 cron / launchd 健康巡检接进来（Step 7 会再深化）。

## 前置条件

- [ ] 已完成 [Step 3](step-3-first-oauth.md)，`token.json` 已落地

## 操作步骤

### 1. 一次性 health 探针

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.health
```

期望输出（JSON 格式，关键字段）：

```json
{
  "server_version": "0.1.x",
  "token_state": "valid",
  "token_age_days": 0.01,
  "token_expires_in_days": 6.99,
  "rate_limit_remaining_per_min": 120,
  "recent_error_count_24h": 0,
  "platform_supported": true
}
```

`token_state` 必须是 `"valid"`；`token_expires_in_days` 必须 ≥ 6.5（刚走完
OAuth 应当是 7.00 - small drift）。

### 2. 解读 `token_state`

| 值 | 含义 | 处置 |
| -- | ---- | ---- |
| `valid` | token.json 存在、JSON 合法、字段齐全、权限正确 | ✅ 可继续 Step 5 |
| `missing` | `token.json` 不存在 | 回 [Step 3](step-3-first-oauth.md) 重跑 |
| `malformed` | JSON 损坏 / 字段缺失 | `mv token.json token.json.bak.$(date +%s)` 后重跑 [Step 3](step-3-first-oauth.md) |
| `insecure_perms` | 权限不是 `600` / 父目录不是 `700` | `chmod 600 token.json && chmod 700 $(dirname token.json)` |

### 3. 提前演练 reauthorize

```bash
# 备份当前 token（不删原 token，仅复制）
cp ~/.local/state/schwab-marketdata-mcp/token.json{,.drill.$(date +%s)}

# 跑 health（仍应 valid，因为原 token 没动）
uv run python -m schwab_marketdata_mcp.health

# 也可以手动 expire：
echo '{}' > ~/.local/state/schwab-marketdata-mcp/token.json
uv run python -m schwab_marketdata_mcp.health
# 期望：token_state == "malformed"

# 恢复原 token：
cp ~/.local/state/schwab-marketdata-mcp/token.json.drill.* ~/.local/state/schwab-marketdata-mcp/token.json
```

## 期望产出

- `health` 模块退出码 = 0
- stdout 含 `"token_state": "valid"` 与 `token_expires_in_days >= 6.5`
- `~/Desktop/SCHWAB_REAUTH_NEEDED.md` 不存在（health 模块只在 token 即将
  过期或损坏时才落地这个文件）

## 验证清单

- [ ] `uv run python -m schwab_marketdata_mcp.health` 退出码 = 0
- [ ] stdout 含 `"token_state": "valid"`
- [ ] `token_expires_in_days >= 6.5`
- [ ] `recent_error_count_24h == 0`（第一次跑必然是 0）
- [ ] `platform_supported == true`（macOS 11+ / Linux）
- [ ] `~/Desktop/SCHWAB_REAUTH_NEEDED.md` 不存在

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| `token_state == "valid"` 但 `token_expires_in_days` 是 `null` | schwab-py 版本过老，`uv sync --upgrade-package schwab-py` |
| `token_state == "insecure_perms"` | `chmod 600 ~/.local/state/schwab-marketdata-mcp/token.json` 与 `chmod 700 ~/.local/state/schwab-marketdata-mcp` |
| `platform_supported == false` | macOS < 11 或 Windows；server v0.1 仅支持 macOS 11+ / Linux |
| stdout 显示 `recent_error_count_24h > 0` 但你刚授权完 | 上一次会话里已有失败；查 `~/.local/state/schwab-marketdata-mcp/logs/server.log` 找 root cause |

## 不要做的事

- **不要** 把 `health` 的 stdout 贴到 issue / chat（含 token 元数据）。先 mask
  `App Key` 与任何 `Bearer ...` 痕迹。

## 下一步

→ [Step 5: First MCP tool call](step-5-first-mcp-tool-call.md)

## 参考

- `health.py` 内部逻辑：MCP 仓库 `src/schwab_marketdata_mcp/health.py`
- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- TokenState 6 种 reason：[`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
