# Quick Start — Step 5: First MCP tool call

> **Goal**: Use a minimal Python MCP client to start the server over
> stdio, call `health_check` and `get_quote("VOO")`, and see a real
> quote come back.

## Prerequisites

- [ ] Step 4 completed and `token_state == "valid"`
- [ ] `uv sync` has been run; the local `mcp` Python SDK is available

## Steps

### 1. Write a verify_token.py

Save the following script to `~/verify_token.py`:

```python
import asyncio
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def verify():
    server_params = StdioServerParameters(
        command="uv",
        args=[
            "--directory",
            os.path.expanduser("~/code/kevinkda/schwab-marketdata-mcp"),
            "run",
            "schwab-marketdata-mcp",
        ],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            # 1) server metadata
            info = await session.call_tool("get_server_info", {})
            print("server_info:", info.content[0].text)

            # 2) token health
            health = await session.call_tool("health_check", {})
            assert '"valid"' in health.content[0].text, \
                f"token not valid: {health.content[0].text}"
            print("health_check OK")

            # 3) real quote
            quote = await session.call_tool("get_quote", {"symbol": "VOO"})
            text = quote.content[0].text
            assert '"error"' not in text or '"error":null' in text, \
                f"get_quote failed: {text}"
            print("get_quote('VOO'):", text[:200], "...")


if __name__ == "__main__":
    asyncio.run(verify())
```

### 2. Run it

```bash
cd /path/to/schwab-marketdata-mcp
uv run python ~/verify_token.py
```

### 3. Read the output

Expect three lines in a row:

```text
server_info: {"server_version":"0.1.x","mcp_sdk_version":"...",...}
health_check OK
get_quote('VOO'): {"symbol":"VOO","quote":{"lastPrice":..., ...}} ...
```

## Expected outcome

- `verify_token.py` exits 0
- `get_quote('VOO')` returned real numbers (no `"error"`)
- A single call did not surface `rate_limit_warning` on stderr

## Verification checklist

- [ ] `verify_token.py` exits 0
- [ ] stdout contains `"server_version":"0.1`
- [ ] stdout contains `"valid"` (from health_check)
- [ ] stdout contains `"symbol":"VOO"` and does **not** contain `"error":"Schwab`
- [ ] `~/.local/state/schwab-marketdata-mcp/logs/server.log` tail has no
      ERROR-level entries

## Common failures

| Symptom | Fix |
| ------- | --- |
| `assert '"valid"' in health.content[0].text` fails | Go back to [Step 4](step-4-token-health-check.md) and resolve token_state |
| `ConnectionRefusedError` / failed to start server | Check the `uv` path and the MCP repo path; replace any hardcoded values with `which uv` / `realpath` |
| `"error":"SchwabRateLimitError"` | Local token bucket already throttled; retry after 30 seconds |
| `"error":"SchwabAuthError"` | Re-run OAuth via [Step 3](step-3-first-oauth.md) |
| `"error":"SchwabValidationError"` | Check whether `verify_token.py` was edited incorrectly; symbol must be UPPERCASE |

## What not to do

- **Do not** edit `verify_token.py` to test 50 symbols — the very first
  run should be the smallest viable sample. Confirm the full chain
  works end-to-end before moving to bulk.
- **Do not** `tee` the stdout directly to a public file — the quote
  contains sensitive timestamps; Schwab Market Data is
  non-redistributable.

## Next step

→ [Step 6: Cursor / Claude integration](step-6-cursor-integration.md)

## References

- Multi-language MCP client integration:
  [`../integration/python-mcp-client.md`](../integration/python-mcp-client.md),
  [`../integration/typescript-mcp-client.md`](../integration/typescript-mcp-client.md),
  [`../integration/rust-mcp-client.md`](../integration/rust-mcp-client.md),
  [`../integration/cli-jq-pipe.md`](../integration/cli-jq-pipe.md)
- Full schema for all 12 tools: [`../tools/index.md`](../tools/index.md)
