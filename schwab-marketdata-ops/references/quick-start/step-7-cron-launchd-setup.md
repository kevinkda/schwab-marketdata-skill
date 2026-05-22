# Quick Start — Step 7: Cron / launchd health watcher

> **目标**：把 `schwab_marketdata_mcp.health` 接入操作系统级定时器，
> 在 refresh_token < 12h 时主动落地
> `~/Desktop/SCHWAB_REAUTH_NEEDED.md` 提醒文件，避免 token 突然过期。

## 前置条件

- [ ] 已完成 [Step 6](step-6-cursor-integration.md)
- [ ] 本机有 cron（Linux / macOS）或 launchd（macOS）

## 推荐巡检频率

Schwab refresh_token 是 **7 天绝对寿命**。建议三种巡检频率叠加：

| 频率 | 用途 |
| ---- | ---- |
| **每 4 小时** | 兜底，捕获意外失效（token 损坏、磁盘满、被外部工具改） |
| **每周日 20:00** | 在 7 天周期最危险的窗口前主动提醒 |
| **每周三 21:00** | 中点提醒，避免周末突然过期 |

## A. cron（Linux & macOS）

```bash
crontab -e
```

加入：

```cron
# Schwab health watcher — every 4 hours
0 */4 * * * cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1

# Sunday 20:00 — pre-weekend reminder
0 20 * * 0 cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1

# Wednesday 21:00 — midweek reminder
0 21 * * 3 cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1
```

把 `/path/to/schwab-marketdata-mcp` 与 `/path/to/uv` 替换为绝对路径
（cron 进程的 PATH 通常很贫瘠，不要靠 PATH 解析）。

## B. launchd（macOS 推荐）

创建 `~/Library/LaunchAgents/dev.kevinkda.schwab-health.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.kevinkda.schwab-health</string>
    <key>ProgramArguments</key>
    <array>
        <string>/absolute/path/to/uv</string>
        <string>--directory</string>
        <string>/absolute/path/to/schwab-marketdata-mcp</string>
        <string>run</string>
        <string>python</string>
        <string>-m</string>
        <string>schwab_marketdata_mcp.health</string>
    </array>
    <key>StartInterval</key>
    <integer>14400</integer>  <!-- 4h -->
    <key>StandardOutPath</key>
    <string>/tmp/schwab-health.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/schwab-health.err</string>
</dict>
</plist>
```

加载：

```bash
launchctl load ~/Library/LaunchAgents/dev.kevinkda.schwab-health.plist
launchctl list | grep schwab-health   # 应看到 entry
```

## C. systemd timer（Linux）

`/etc/systemd/user/schwab-health.service`：

```ini
[Unit]
Description=Schwab MCP health probe

[Service]
Type=oneshot
WorkingDirectory=%h/code/kevinkda/schwab-marketdata-mcp
ExecStart=%h/.local/bin/uv run python -m schwab_marketdata_mcp.health
StandardOutput=append:/tmp/schwab-health.log
StandardError=append:/tmp/schwab-health.err
```

`/etc/systemd/user/schwab-health.timer`：

```ini
[Unit]
Description=Run Schwab health probe every 4h

[Timer]
OnBootSec=15min
OnUnitActiveSec=4h
Unit=schwab-health.service

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now schwab-health.timer
systemctl --user list-timers | grep schwab
```

## 自检通知通道

跑一次 self-test 确认通知系统能弹出来：

```bash
cd /path/to/schwab-marketdata-mcp
bash scripts/notifier-self-test.sh
```

期望：

- macOS：通知中心弹一条 `Schwab MCP self-test...`
- Linux：`notify-send` 弹 critical 通知
- 桌面落地一个 `~/Desktop/SCHWAB_REAUTH_NEEDED.md` marker（之后可删）

## 期望产出

- 三种定时器至少有**一种**已激活
- 桌面通知系统跑过 self-test 能弹通知
- `/tmp/schwab-health.log` 在第一个巡检周期后有日志条目

## 验证清单

- [ ] **cron**：`crontab -l | grep schwab` 显示 entry
- [ ] **launchd**：`launchctl list | grep schwab-health` 显示 entry，
      `Status` = 0
- [ ] **systemd**：`systemctl --user list-timers | grep schwab` 显示
      next run 时间
- [ ] 4 小时后 `/tmp/schwab-health.log` 有新日志
- [ ] 当故意 expire token（参 Step 4 演练）时，cron 触发后桌面会出现
      `SCHWAB_REAUTH_NEEDED.md` 文件

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| `cron` 跑了但 token 状态不更新 | 多半是 cron 环境 PATH 太贫瘠；用绝对路径，不要依赖 PATH 解析 |
| macOS 通知不弹 | System Settings → Privacy & Security → Automation，允许 Terminal/iTerm 控制 System Events |
| launchd plist 加载失败 | 用 `plutil -lint dev.kevinkda.schwab-health.plist` 检查格式；XML 里的 `&` 必须转义 |
| systemd timer 状态 `inactive (dead)` | `systemctl --user status schwab-health.service` 看具体错误；多半是 WorkingDirectory / ExecStart 路径 |
| log 里反复 `recent_error_count_24h` 持续递增 | 真有问题；逐条对照 [`../troubleshooting/auth-overview.md`](../troubleshooting/auth-overview.md) |

## 不要做的事

- **不要** 把巡检频率调到 < 1h（无意义浪费 quota）。
- **不要** 让 cron 把 stdout 写到公共目录 / 公共日志服务器（含 token
  元数据）。
- **不要** 在 cron 里直接跑 `auth login_flow`（OAuth 必须人参与）。

## 下一步

恭喜！至此 Quick Start 完成。继续阅读：

- [Tool reference index](../tools/index.md) — 12 个 tool 完整 schema
- [Integration code samples](../integration/) — Python / TS / Rust / CLI client
- [Troubleshooting overview](../troubleshooting/auth-overview.md)
- [FAQ](../faq.md)

## 参考

- `cron.example` 完整模板：MCP 仓库 `docs/cron.example`
- self-test 脚本：MCP 仓库 `scripts/notifier-self-test.sh`
- token lifecycle：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
