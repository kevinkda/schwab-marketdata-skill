# Integration — Python MCP client

> Use the MCP client from your own **Python application** to call
> the `schwab-marketdata-mcp` server. Uses the official `mcp`
> Python SDK (<https://pypi.org/project/mcp/>).

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/integration/python-mcp-client.md`](../../../schwab-marketdata-ops/references/integration/python-mcp-client.md).

## When to use

- You're writing a Python bot / dashboard / Jupyter notebook
- You want to call the 12 tools directly without going through
  Cursor / Claude UI
- You need to post-process Schwab data (with pandas / polars) and
  write it back into your own datastore or markdown

## Prerequisites

- Python ≥ 3.10
- `uv` installed
- [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)
  completed (token ready)

## Install

```bash
mkdir my-schwab-app && cd my-schwab-app
uv init
uv add mcp
```

`uv add mcp` installs the official Anthropic-maintained `mcp`
Python SDK.

## Minimal hello-world: health_check

```python
# hello.py
import asyncio
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SERVER_REPO = os.path.expanduser("~/code/kevinkda/schwab-marketdata-mcp")


async def main() -> None:
    server_params = StdioServerParameters(
        command="uv",
        args=[
            "--directory",
            SERVER_REPO,
            "run",
            "schwab-marketdata-mcp",
        ],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            result = await session.call_tool("health_check", {})
            print(result.content[0].text)


if __name__ == "__main__":
    asyncio.run(main())
```

```bash
uv run python hello.py
# Expected:
#   {"server_version": "0.1.x", "token_state": "valid", ...}
```

## Calling get_quote (with error handling)

```python
import asyncio
import json
import os

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


SERVER_REPO = os.path.expanduser("~/code/kevinkda/schwab-marketdata-mcp")


async def get_quote(symbol: str) -> dict:
    server_params = StdioServerParameters(
        command="uv",
        args=["--directory", SERVER_REPO, "run", "schwab-marketdata-mcp"],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            res = await session.call_tool("get_quote", {"symbol": symbol})
            payload = json.loads(res.content[0].text)

            if payload.get("error"):
                raise SchwabError(payload["error"], payload)
            return payload


class SchwabError(Exception):
    def __init__(self, error_type: str, payload: dict) -> None:
        super().__init__(f"{error_type}: {payload}")
        self.error_type = error_type
        self.payload = payload


if __name__ == "__main__":
    quote = asyncio.run(get_quote("VOO"))
    print(quote["symbol"], quote["quote"]["lastPrice"])
```

## Reuse a long session (recommended)

Spinning up the server process per tool call is expensive (~500ms
startup). Wrap a long-lived session:

```python
# schwab_client.py
import asyncio
import json
import os
from contextlib import AsyncExitStack

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


class SchwabClient:
    def __init__(self, server_repo: str) -> None:
        self._server_repo = server_repo
        self._stack: AsyncExitStack | None = None
        self._session: ClientSession | None = None

    async def __aenter__(self) -> "SchwabClient":
        self._stack = AsyncExitStack()
        params = StdioServerParameters(
            command="uv",
            args=["--directory", self._server_repo, "run", "schwab-marketdata-mcp"],
        )
        read, write = await self._stack.enter_async_context(stdio_client(params))
        self._session = await self._stack.enter_async_context(ClientSession(read, write))
        await self._session.initialize()
        return self

    async def __aexit__(self, *exc) -> None:
        await self._stack.aclose()

    async def call(self, name: str, args: dict) -> dict:
        assert self._session is not None
        res = await self._session.call_tool(name, args)
        payload = json.loads(res.content[0].text)
        if payload.get("error"):
            raise RuntimeError(payload["error"])
        return payload


async def demo() -> None:
    repo = os.path.expanduser("~/code/kevinkda/schwab-marketdata-mcp")
    async with SchwabClient(repo) as c:
        info = await c.call("get_server_info", {})
        print("server_version:", info["server_version"])

        for sym in ["VOO", "QQQ", "SPY"]:
            quote = await c.call("get_quote", {"symbol": sym})
            print(sym, "=", quote["quote"]["lastPrice"])


if __name__ == "__main__":
    asyncio.run(demo())
```

## Error-handling template

```python
async def safe_call(client: SchwabClient, name: str, args: dict, max_retries: int = 2):
    """Retry / early-exit for common error categories."""
    for attempt in range(max_retries + 1):
        try:
            return await client.call(name, args)
        except RuntimeError as e:
            msg = str(e)
            if "SchwabValidationError" in msg:
                raise   # do not retry; let the caller fix the parameter
            if "SchwabAuthError" in msg:
                raise   # human intervention required to run auth login_flow
            if "SchwabRateLimitError" in msg and attempt < max_retries:
                await asyncio.sleep(2 ** attempt)
                continue
            raise
```

## Performance guidance

- **Long sessions**: use the `SchwabClient` above to reuse a
  session; do not spin up the server per call.
- **Batch first**: prefer `get_quotes(symbols=[...])` (≤ 50) over
  looping `get_quote`.
- **Local rate limit**: default 120 req/min; for large batches set
  `SCHWAB_RATE_LIMIT_PER_MIN=80` in `.env` so local throttling
  fires before Schwab does, avoiding server-side accounting.

## What not to do

- **Do not** run multiple `SchwabClient()` instances against the
  same MCP server in parallel — multiple server processes each
  count their own token-bucket (120 × N), but Schwab's quota is
  still ~120/min, so you will overrun.
- **Do not** hardcode the token.json path in the client — the
  server reads `XDG_STATE_HOME` itself.
- **Do not** put `SCHWAB_APP_KEY` and similar secrets into
  `mcp.json`-style registration files — always use `.env`.

## References

- Official `mcp` Python SDK: <https://github.com/modelcontextprotocol/python-sdk>
- Full schema for the 12 tools: [`../tools/index.md`](../tools/index.md)
- Error triage: [`../error-recovery.md`](../error-recovery.md)
