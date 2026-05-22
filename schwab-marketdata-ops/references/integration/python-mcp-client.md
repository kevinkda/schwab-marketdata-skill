# Integration — Python MCP client

> 在你自己的 **Python 应用**里作为 MCP 客户端调用
> `schwab-marketdata-mcp` server。用官方 `mcp` Python SDK
> （<https://pypi.org/project/mcp/>）。

## 适用场景

- 你正在写一个 Python bot / dashboard / Jupyter notebook
- 你想要在不依赖 Cursor / Claude UI 的情况下直接调 12 个 tool
- 你需要把 schwab 数据再处理（pandas / polars 加工）后写到自己的数据
  库或 markdown

## 前置条件

- Python ≥ 3.10
- `uv` 已安装
- 已完成 [Quick Start Step 1-4](../quick-start/step-1-developer-portal-app.md)
  （token 已就绪）

## 安装

```bash
mkdir my-schwab-app && cd my-schwab-app
uv init
uv add mcp
```

`uv add mcp` 安装的是官方 Anthropic 维护的 `mcp` Python SDK。

## 最小 hello-world：health_check

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
# 期望：
#   {"server_version": "0.1.x", "token_state": "valid", ...}
```

## 调 get_quote（含错误处理）

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

## 长会话复用（推荐）

每次 tool call 都开关一次 server 进程**性价比低**（启动 ~500ms）。
封装一个 long-lived session：

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

## 错误处理模板

```python
async def safe_call(client: SchwabClient, name: str, args: dict, max_retries: int = 2):
    """对常见错误类型做重试 / 早退。"""
    for attempt in range(max_retries + 1):
        try:
            return await client.call(name, args)
        except RuntimeError as e:
            msg = str(e)
            if "SchwabValidationError" in msg:
                raise   # 不要重试，让上层修参数
            if "SchwabAuthError" in msg:
                raise   # 需要人介入走 auth login_flow
            if "SchwabRateLimitError" in msg and attempt < max_retries:
                await asyncio.sleep(2 ** attempt)
                continue
            raise
```

## 性能建议

- **长会话**：用上面的 `SchwabClient` 复用 session，不要每次 call 都
  启动 server。
- **批量优先**：能用 `get_quotes(symbols=[...])`（≤ 50）就别循环
  `get_quote`。
- **本机限流**：默认 120 req/min，大批量任务在 `.env` 里调低
  `SCHWAB_RATE_LIMIT_PER_MIN=80` 让本机先于 Schwab 拦下，避免被服务端
  记账。

## 不要做的事

- **不要** 在多个 `SchwabClient()` 实例并发跑同一台 MCP server —— 启动多
  份 server 进程会让 token-bucket 各自计数（120 × N），但 Schwab 那边的
  配额还是 ~120/min，必然超额。
- **不要** 把 token.json 路径硬编码在 client 里 —— server 自己读
  `XDG_STATE_HOME`。
- **不要** 在 `mcp.json` 风格的注册文件里加 `SCHWAB_APP_KEY` 等 secret
  —— 始终走 `.env`。

## 参考

- 官方 `mcp` Python SDK：<https://github.com/modelcontextprotocol/python-sdk>
- 12 tool 完整 schema：[`../tools/index.md`](../tools/index.md)
- 错误分流：[`../error-recovery.md`](../error-recovery.md)
