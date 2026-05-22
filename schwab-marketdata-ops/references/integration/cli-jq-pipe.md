# Integration — CLI / `jq` over stdin/stdout

> 完全不依赖 SDK，用 shell 直接和 server 走 JSON-RPC over stdio。最
> hackable 的方式，适合一次性验证、shell 脚本、或写 CI smoke test。

## 适用场景

- 你只想做一次 health 检查，不想引入任何语言运行时
- 写 CI smoke test（GitHub Actions / Buildkite）
- 在远程机上做 ad-hoc 调试

## 前置

- `jq`（<https://jqlang.github.io/jq/>）已安装
- `uv` 已安装
- 已完成 [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)

## 基础协议

MCP 走 newline-delimited JSON-RPC（每条消息一行，`\n` 结尾）。前 1-2 条
是 `initialize` + `notifications/initialized`，之后才能 `tools/call`。

## 一行 shell：调 `health_check`

```bash
cd /path/to/schwab-marketdata-mcp

(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"health_check","arguments":{}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson'
```

期望输出（一行 JSON）：

```json
{"server_version":"0.1.x","token_state":"valid","token_age_days":0.5,"token_expires_in_days":6.5,"rate_limit_remaining_per_min":120,"recent_error_count_24h":0,"platform_supported":true}
```

## 调 `get_quote("VOO")`

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_quote","arguments":{"symbol":"VOO"}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson | .quote.lastPrice'
```

期望输出（一个数字）：

```text
527.34
```

## 用 `coproc`（bash）建立长会话

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /path/to/schwab-marketdata-mcp

coproc MCP { uv run schwab-marketdata-mcp 2>/dev/null; }

# initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}' >&"${MCP[1]}"
echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' >&"${MCP[1]}"

# 跳过 initialize 响应
read -r _initialize_resp <&"${MCP[0]}"

# 循环调多个 quote
for sym in VOO QQQ SPY; do
  printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_quote","arguments":{"symbol":"%s"}}}\n' "$sym" >&"${MCP[1]}"
  read -r resp <&"${MCP[0]}"
  price=$(echo "$resp" | jq -r '.result.content[0].text | fromjson | .quote.lastPrice')
  echo "$sym = $price"
done

# 关闭 server
exec {MCP[1]}>&-
wait $MCP_PID 2>/dev/null || true
```

## 在 GitHub Actions 里做 smoke

```yaml
- name: Schwab MCP smoke
  run: |
    (
      echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"ci","version":"0.0"}}}'
      echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
      echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"health_check","arguments":{}}}'
    ) | uv run schwab-marketdata-mcp 2>/dev/null \
      | jq -e 'select(.id==2) | .result.content[0].text | fromjson | .token_state == "valid"'
```

`jq -e` 在 token_state 不是 `"valid"` 时返回非零，让 CI 失败。

## 常见错误

| 现象                                  | 处置                                                                |
| ------------------------------------- | ------------------------------------------------------------------- |
| `jq` 报 `parse error: Invalid numeric literal` | server 把 stderr / stdout 混在一起；改成 `2>/dev/null`               |
| `select(.id==2)` 选不到任何东西        | 协议顺序错；`notifications/initialized` 必须在 `initialize` 之后立即发 |
| 输出全是 `null`                       | `tools/call` 的 `id` 与 jq 里 select 的 id 不一致；检查序号           |
| 业务 call 失败但 jq 看不到 `error`    | 错误在 result.content[0].text 里，要 `| fromjson | .error`            |

## 不要做的事

- **不要** 把 stdout / stderr 同时管道到 jq —— stderr 上的人类可读
  log 会破坏 JSON-RPC 流，必须 `2>/dev/null` 或 `2>&-`。
- **不要** 在长会话里漏掉 `notifications/initialized` —— server 会拒绝
  后续 `tools/call`。
- **不要** 用同一个 `id` 发多次 request —— server 是合法的 JSON-RPC
  实现，重复 id 会让响应错配。

## 参考

- JSON-RPC 2.0 规范：<https://www.jsonrpc.org/specification>
- MCP 规范：<https://modelcontextprotocol.io/specification>
- Python / TypeScript / Rust 等价文档：[`python-mcp-client.md`](python-mcp-client.md) / [`typescript-mcp-client.md`](typescript-mcp-client.md) / [`rust-mcp-client.md`](rust-mcp-client.md)
