# Quick Start — Step 6: Register the MCP server in Cursor / Claude

> **目标**：把 `schwab-marketdata-mcp` 注册到 Cursor 或 Claude Code，让
> AI agent 能直接调用 12 个 tool。

## 前置条件

- [ ] 已完成 [Step 5](step-5-first-mcp-tool-call.md)，最小 verify 通过
- [ ] 本机已安装 Cursor IDE 或 Claude Code
- [ ] `which uv` 输出可用的绝对路径

## A. Cursor 注册

编辑 `~/.cursor/mcp.json`（不存在就创建），合并以下结构（不要覆盖
原有 `mcpServers`）：

```json
{
  "mcpServers": {
    "schwab-marketdata": {
      "command": "/absolute/path/to/uv",
      "args": [
        "--directory",
        "/absolute/path/to/schwab-marketdata-mcp",
        "run",
        "schwab-marketdata-mcp"
      ],
      "env": {
        "LOG_LEVEL": "WARNING",
        "SCHWAB_RATE_LIMIT_PER_MIN": "120"
      },
      "stderr": "/absolute/path/to/state/schwab-marketdata-mcp/logs/server.log"
    }
  }
}
```

`command` 必须是 **绝对路径**（不要写 `uv` 或 `~/.local/bin/uv`）。
`args[1]` 必须是 MCP 仓库的 **绝对路径**。

### 重启 Cursor

```bash
# macOS
osascript -e 'quit app "Cursor"'
open -a Cursor

# Linux
pkill -f cursor || true && cursor &
```

### 验证

打开 Cursor → `Cmd/Ctrl + L` 开 chat → 输入：

```text
Use the schwab-marketdata MCP tool get_server_info to print the server info.
```

期望 agent 调用 `get_server_info` 并返回 `server_version` 等字段。

## B. Claude Code 注册

Claude Code 走 `~/.claude/skills/` + `~/.claude/mcp.json`，结构与 Cursor
一致。

```bash
mkdir -p ~/.claude
cp ~/.cursor/mcp.json ~/.claude/mcp.json   # 或者手写一份
```

## C. 同步注册两个 skill 包

```bash
# 把当前 skill 仓库的两个 skill 软链到 ~/.cursor/skills/
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-ops" \
      ~/.cursor/skills/schwab-marketdata-ops
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-workflows" \
      ~/.cursor/skills/schwab-marketdata-workflows

# Claude Code 同样：
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-ops" \
      ~/.claude/skills/schwab-marketdata-ops
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-workflows" \
      ~/.claude/skills/schwab-marketdata-workflows
```

## 期望产出

- `~/.cursor/mcp.json`（或 `~/.claude/mcp.json`）含 `schwab-marketdata`
  entry
- 重启 Cursor / Claude 后，chat 能成功调 `get_server_info`
- 两个 skill 软链可见：`ls -la ~/.cursor/skills/`

## 验证清单

- [ ] `cat ~/.cursor/mcp.json | python -m json.tool` exit 0（JSON 合法）
- [ ] Cursor 重启后，状态栏 / chat 显示 MCP server 已连接
- [ ] Chat 中跑 `get_server_info` 返回非 error 结果
- [ ] `~/.local/state/schwab-marketdata-mcp/logs/server.log` 中
      新增了一条 `received_initialize` 之类的日志
- [ ] `ls -la ~/.cursor/skills/schwab-marketdata-*` 显示两个软链

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| Cursor 状态栏 MCP 显示 `Disconnected` | `command` / `args[1]` 写的是相对路径或 `~`；改成绝对路径 |
| chat 调 tool 时报 `command not found: uv` | `command` 必须是 `which uv` 的真实路径，不是 `uv` |
| 日志显示 `Permission denied: token.json` | Cursor 进程的环境变量与 shell 不同；用 `--config-dir` CLI 在 args 里指定 token 路径 |
| `${HOME}` 没被展开 | 部分 Cursor 版本不展开；改写绝对路径 |
| stderr 文件路径不存在 | 先 `mkdir -p ~/.local/state/schwab-marketdata-mcp/logs` |

## 不要做的事

- **不要** 把 App Key / App Secret 直接放到 `mcp.json` 的 `env` 字段
  里。`schwab-marketdata-mcp` server 只从 `.env` 读 secret，绝不从
  `mcp.json` 注入的 env var 读。
- **不要** 把 `schwab_marketdata_mcp.auth` 当作 MCP server 注册（auth CLI
  用 stdout 与浏览器交换 OAuth code，会破坏 JSON-RPC 协议）。

## 下一步

→ [Step 7: Cron / launchd health watcher](step-7-cron-launchd-setup.md)

## 参考

- 完整注册指南：MCP 仓库 `docs/REGISTER.md`
- Compatibility matrix：本仓库 `README.md`
- 多语言 MCP client：[`../integration/`](../integration/)
