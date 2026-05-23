# Integration — CLI / `jq` over stdin/stdout

> Talk to the server via JSON-RPC over stdio with no SDK. The most
> hackable approach — good for one-shot validation, shell scripts,
> or CI smoke tests.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/integration/cli-jq-pipe.md`](../../../schwab-marketdata-ops/references/integration/cli-jq-pipe.md).

## When to use

- You only want a one-off health check without bringing in a
  language runtime
- You're writing a CI smoke test (GitHub Actions / Buildkite)
- You're doing ad-hoc debugging on a remote machine

## Prerequisites

- `jq` installed (<https://jqlang.github.io/jq/>)
- `uv` installed
- [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)
  completed

## Protocol basics

MCP uses newline-delimited JSON-RPC (one message per line, `\n`
terminated). The first 1-2 messages are `initialize` +
`notifications/initialized`; only after that may you call
`tools/call`.

## One-liner: `health_check`

```bash
cd /path/to/schwab-marketdata-mcp

(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"health_check","arguments":{}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson'
```

Expected output (one JSON line):

```json
{"server_version":"0.1.x","token_state":"valid","token_age_days":0.5,"token_expires_in_days":6.5,"rate_limit_remaining_per_min":120,"recent_error_count_24h":0,"platform_supported":true}
```

## Calling `get_quote("VOO")`

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_quote","arguments":{"symbol":"VOO"}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson | .quote.lastPrice'
```

Expected output (a single number):

```text
527.34
```

## Long-running session via `coproc` (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /path/to/schwab-marketdata-mcp

coproc MCP { uv run schwab-marketdata-mcp 2>/dev/null; }

# initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}' >&"${MCP[1]}"
echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' >&"${MCP[1]}"

# Skip the initialize response
read -r _initialize_resp <&"${MCP[0]}"

# Loop through several quotes
for sym in VOO QQQ SPY; do
  printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_quote","arguments":{"symbol":"%s"}}}\n' "$sym" >&"${MCP[1]}"
  read -r resp <&"${MCP[0]}"
  price=$(echo "$resp" | jq -r '.result.content[0].text | fromjson | .quote.lastPrice')
  echo "$sym = $price"
done

# Stop the server
exec {MCP[1]}>&-
wait $MCP_PID 2>/dev/null || true
```

## Smoke test in GitHub Actions

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

`jq -e` exits non-zero when token_state is not `"valid"`, failing
CI.

## Common errors

| Symptom                                  | Action                                                              |
| ---------------------------------------- | ------------------------------------------------------------------- |
| `jq` reports `parse error: Invalid numeric literal` | The server interleaves stderr / stdout; redirect with `2>/dev/null` |
| `select(.id==2)` returns nothing          | Protocol order is wrong; `notifications/initialized` must immediately follow `initialize` |
| Output is all `null`                     | The `id` on `tools/call` does not match the id used in jq's select; check the numbering |
| The business call failed but jq does not surface `error` | The error sits in `result.content[0].text`, so use `\| fromjson \| .error` |

## What not to do

- **Do not** pipe both stdout and stderr into jq — human-readable
  log lines on stderr corrupt the JSON-RPC stream; redirect with
  `2>/dev/null` or `2>&-`.
- **Do not** skip `notifications/initialized` in long sessions —
  the server will reject subsequent `tools/call` invocations.
- **Do not** reuse the same `id` for multiple requests — the server
  is a conformant JSON-RPC implementation; duplicate ids cause
  response correlation to fail.

## References

- JSON-RPC 2.0 spec: <https://www.jsonrpc.org/specification>
- MCP spec: <https://modelcontextprotocol.io/specification>
- Equivalent docs for Python / TypeScript / Rust:
  [`python-mcp-client.md`](python-mcp-client.md) /
  [`typescript-mcp-client.md`](typescript-mcp-client.md) /
  [`rust-mcp-client.md`](rust-mcp-client.md)
