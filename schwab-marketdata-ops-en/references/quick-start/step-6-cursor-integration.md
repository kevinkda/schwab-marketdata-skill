# Quick Start — Step 6: Register the MCP server in Cursor / Claude

> **Goal**: Register `schwab-marketdata-mcp` with Cursor or Claude Code
> so that the AI agent can directly invoke all 12 tools.

## Prerequisites

- [ ] Step 5 completed and the minimal verify script passes
- [ ] Cursor IDE or Claude Code installed locally
- [ ] `which uv` prints a usable absolute path

## A. Register with Cursor

Edit `~/.cursor/mcp.json` (create it if missing) and merge the
following structure (do not overwrite the existing `mcpServers`):

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

`command` must be an **absolute path** (not `uv` and not
`~/.local/bin/uv`). `args[1]` must be the **absolute path** to the MCP
repo.

### Restart Cursor

```bash
# macOS
osascript -e 'quit app "Cursor"'
open -a Cursor

# Linux
pkill -f cursor || true && cursor &
```

### Verify

Open Cursor → `Cmd/Ctrl + L` to open chat → type:

```text
Use the schwab-marketdata MCP tool get_server_info to print the server info.
```

Expect the agent to call `get_server_info` and return fields like
`server_version`.

## B. Register with Claude Code

Claude Code uses `~/.claude/skills/` + `~/.claude/mcp.json` with the
same structure as Cursor.

```bash
mkdir -p ~/.claude
cp ~/.cursor/mcp.json ~/.claude/mcp.json   # or write a fresh one by hand
```

## C. Register both skill packages

```bash
# Symlink the two skills from this repo into ~/.cursor/skills/
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-ops-en" \
      ~/.cursor/skills/schwab-marketdata-ops-en
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-workflows-en" \
      ~/.cursor/skills/schwab-marketdata-workflows-en

# Same for Claude Code:
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-ops-en" \
      ~/.claude/skills/schwab-marketdata-ops-en
ln -s "/path/to/schwab-marketdata-skill/schwab-marketdata-workflows-en" \
      ~/.claude/skills/schwab-marketdata-workflows-en
```

## Expected outcome

- `~/.cursor/mcp.json` (or `~/.claude/mcp.json`) contains the
  `schwab-marketdata` entry
- After restarting Cursor / Claude, chat can successfully call
  `get_server_info`
- Both skill symlinks visible: `ls -la ~/.cursor/skills/`

## Verification checklist

- [ ] `cat ~/.cursor/mcp.json | python -m json.tool` exits 0 (valid JSON)
- [ ] After restart, Cursor's status bar / chat shows the MCP server is
      connected
- [ ] In chat, calling `get_server_info` returns a non-error result
- [ ] `~/.local/state/schwab-marketdata-mcp/logs/server.log` shows a
      new `received_initialize` (or similar) log line
- [ ] `ls -la ~/.cursor/skills/schwab-marketdata-*` lists both symlinks

## Common failures

| Symptom | Fix |
| ------- | --- |
| Cursor status bar shows MCP `Disconnected` | `command` / `args[1]` is a relative path or `~`; use absolute paths |
| chat calls a tool and reports `command not found: uv` | `command` must be the real path from `which uv`, not `uv` |
| logs show `Permission denied: token.json` | The Cursor process has a different env from your shell; use the `--config-dir` CLI flag in args to specify the token path |
| `${HOME}` not expanded | Some Cursor versions don't expand it; use absolute paths |
| stderr path does not exist | First `mkdir -p ~/.local/state/schwab-marketdata-mcp/logs` |

## What not to do

- **Do not** put App Key / App Secret directly into the `env` field of
  `mcp.json`. The `schwab-marketdata-mcp` server reads secrets only
  from `.env`, never from the env injected by `mcp.json`.
- **Do not** register `schwab_marketdata_mcp.auth` as an MCP server
  (the auth CLI uses stdout to exchange OAuth codes with the browser
  and would corrupt the JSON-RPC protocol).

## Next step

→ [Step 7: Cron / launchd health watcher](step-7-cron-launchd-setup.md)

## References

- Full registration guide: MCP repo `docs/REGISTER.md`
- Compatibility matrix: this repo's `README.md`
- Multi-language MCP clients: [`../integration/`](../integration/)
