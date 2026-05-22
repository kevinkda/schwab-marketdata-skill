# Troubleshooting — `SchwabAuthError(reason="refresh_token_expired_soon")`

**预警**类错误：refresh_token 7 天绝对寿命剩余 < 12 小时窗口，强烈
建议立即 reauthorize，不要拖到真正过期。

## Symptom

- `health_check()` 返回 `token_expires_in_days < 0.5`
- server 启动时 stderr 出现 `WARNING refresh_token_expires_soon`
- cron `health.py` 在 `~/Desktop/SCHWAB_REAUTH_NEEDED.md` 落地 marker
- macOS notification center / Linux notify-send 弹通知

## Root cause

refresh_token 的 7 天**绝对**寿命快到了。这是 Schwab OAuth 的硬限制，
**无法绕过**。任何客户端方式（包括 schwab-py）都不能延长。

## 检查命令

```bash
uv run python -m schwab_marketdata_mcp.health
# 看 token_expires_in_days；< 0.5 = 12 小时内过期
```

## 修复命令

普通笔记本（推荐）：

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
```

SSH-only / headless：

```bash
uv run python -m schwab_marketdata_mcp.auth manual_flow
```

## 验证命令

```bash
uv run python -m schwab_marketdata_mcp.health
# 期望：exit 0；token_state == "valid"；token_expires_in_days >= 6.5
ls ~/Desktop/SCHWAB_REAUTH_NEEDED.md 2>/dev/null && echo "marker still exists"
# 期望：marker 文件已被删除（health 模块在 valid 时清理）
```

## 为什么是 12 小时不是 1 小时？

历史经验：Schwab 服务端的 refresh_token 失效有 ~30 分钟的不确定窗口
（缓存与服务器时钟漂移），加上桌面通知延迟（cron 4h 周期 + 用户看到
通知后真正坐下来 reauthorize 的时间），12 小时是一个有合理缓冲的提
前量。

## 不要做的事

- **不要** 等到完全过期才处理 —— 那时 agent 还在做的工作会全部失败。
- **不要** 试图用 cron 自动化 `auth login_flow` —— 必须人参与。

## 参考

- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- 完全过期处置：[`auth-refresh-expired.md`](auth-refresh-expired.md)
- 健康巡检：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
