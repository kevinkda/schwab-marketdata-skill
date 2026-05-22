# Quick Start — Step 7: Cron / launchd health watcher

> **Goal**: Wire `schwab_marketdata_mcp.health` into an OS-level
> scheduler so that, when refresh_token has < 12h to live, it
> proactively writes a `~/Desktop/SCHWAB_REAUTH_NEEDED.md` reminder
> file — preventing surprise expirations.

## Prerequisites

- [ ] Step 6 completed
- [ ] cron (Linux / macOS) or launchd (macOS) available locally

## Recommended probe frequency

The Schwab refresh_token has a **hard 7-day lifetime**. We recommend
overlapping three cadences:

| Cadence | Purpose |
| ------- | ------- |
| **Every 4 hours** | Safety net; catches unexpected invalidation (corrupt token, full disk, external tools modifying it) |
| **Sundays at 20:00** | Proactive reminder right before the most dangerous window of the 7-day cycle |
| **Wednesdays at 21:00** | Mid-week reminder to avoid weekend surprise expiry |

## A. cron (Linux & macOS)

```bash
crontab -e
```

Add:

```cron
# Schwab health watcher — every 4 hours
0 */4 * * * cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1

# Sunday 20:00 — pre-weekend reminder
0 20 * * 0 cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1

# Wednesday 21:00 — midweek reminder
0 21 * * 3 cd /path/to/schwab-marketdata-mcp && /path/to/uv run python -m schwab_marketdata_mcp.health > /tmp/schwab-health.log 2>&1
```

Replace `/path/to/schwab-marketdata-mcp` and `/path/to/uv` with
absolute paths (cron processes have a very minimal PATH; do not rely
on PATH resolution).

## B. launchd (recommended on macOS)

Create `~/Library/LaunchAgents/dev.kevinkda.schwab-health.plist`:

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

Load it:

```bash
launchctl load ~/Library/LaunchAgents/dev.kevinkda.schwab-health.plist
launchctl list | grep schwab-health   # entry should appear
```

## C. systemd timer (Linux)

`/etc/systemd/user/schwab-health.service`:

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

`/etc/systemd/user/schwab-health.timer`:

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

## Notification channel self-test

Run a self-test to confirm the notification system can pop up alerts:

```bash
cd /path/to/schwab-marketdata-mcp
bash scripts/notifier-self-test.sh
```

Expected:

- macOS: Notification Center shows `Schwab MCP self-test...`
- Linux: `notify-send` displays a critical notification
- A `~/Desktop/SCHWAB_REAUTH_NEEDED.md` marker file lands on the
  desktop (you can delete it afterwards)

## Expected outcome

- At least **one** of the three schedulers is active
- Desktop notification system passes the self-test
- `/tmp/schwab-health.log` has log entries after the first probe cycle

## Verification checklist

- [ ] **cron**: `crontab -l | grep schwab` shows the entry
- [ ] **launchd**: `launchctl list | grep schwab-health` shows the
      entry with `Status` = 0
- [ ] **systemd**: `systemctl --user list-timers | grep schwab` shows
      the next run time
- [ ] 4 hours later, `/tmp/schwab-health.log` has new entries
- [ ] When you deliberately expire the token (cf. Step 4 drill), the
      next cron-triggered probe produces `SCHWAB_REAUTH_NEEDED.md` on
      the desktop

## Common failures

| Symptom | Fix |
| ------- | --- |
| `cron` runs but token state never updates | Usually cron's PATH is too minimal; use absolute paths and don't rely on PATH resolution |
| macOS notifications don't pop up | System Settings → Privacy & Security → Automation, allow Terminal/iTerm to control System Events |
| launchd plist fails to load | `plutil -lint dev.kevinkda.schwab-health.plist` to check formatting; XML `&` must be escaped |
| systemd timer status `inactive (dead)` | `systemctl --user status schwab-health.service` for the actual error; usually a WorkingDirectory / ExecStart path issue |
| log keeps incrementing `recent_error_count_24h` | Real problem; cross-reference [`../troubleshooting/auth-overview.md`](../troubleshooting/auth-overview.md) |

## What not to do

- **Do not** set the probe frequency below 1 hour (pointless quota
  waste).
- **Do not** let cron write stdout to a shared directory / log server
  (it includes token metadata).
- **Do not** invoke `auth login_flow` from cron (OAuth always requires
  a human).

## Next step

Congratulations! Quick Start is complete. Continue with:

- [Tool reference index](../tools/index.md) — full schema for the 12 tools
- [Integration code samples](../integration/) — Python / TS / Rust / CLI clients
- [Troubleshooting overview](../troubleshooting/auth-overview.md)
- [FAQ](../faq.md)

## References

- Full `cron.example` template: MCP repo `docs/cron.example`
- self-test script: MCP repo `scripts/notifier-self-test.sh`
- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
