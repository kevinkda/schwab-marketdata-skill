# Quick Start — Step 5: First MCP tool call

> **目标**：用一个最小 Python MCP client 通过 stdio 启动 server、调用
> `health_check` 与 `get_quote("VOO")`，看到一条真实报价返回。

## 前置条件

- [ ] 已完成 [Step 4](step-4-token-health-check.md)，`token_state == "valid"`
- [ ] 已 `uv sync`，本机 `mcp` Python SDK 可用

## 操作步骤

### 1. 写一个 verify_token.py

把以下脚本保存到 `~/verify_token.py`：

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

### 2. 运行

```bash
cd /path/to/schwab-marketdata-mcp
uv run python ~/verify_token.py
```

### 3. 解读输出

期望连续三行：

```text
server_info: {"server_version":"0.1.x","mcp_sdk_version":"...",...}
health_check OK
get_quote('VOO'): {"symbol":"VOO","quote":{"lastPrice":..., ...}} ...
```

## 期望产出

- `verify_token.py` 退出码 = 0
- 看到 `get_quote('VOO')` 返回真实数字（非 `"error"`）
- 单次调用 stderr 不出现 `rate_limit_warning`

## 验证清单

- [ ] `verify_token.py` 退出码 = 0
- [ ] stdout 包含 `"server_version":"0.1`
- [ ] stdout 包含 `"valid"`（来自 health_check）
- [ ] stdout 包含 `"symbol":"VOO"` 且**不**包含 `"error":"Schwab`
- [ ] `~/.local/state/schwab-marketdata-mcp/logs/server.log` 末尾没有
      ERROR 级别日志

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| `assert '"valid"' in health.content[0].text` 失败 | 回 [Step 4](step-4-token-health-check.md) 处置 token_state |
| `ConnectionRefusedError` / 启动 server 失败 | 检查 `uv` 路径与 MCP 仓库路径；用 `which uv` / `realpath` 替换硬编码 |
| 看到 `"error":"SchwabRateLimitError"` | 已被本机 token-bucket 拦下；30 秒后再试一次 |
| 看到 `"error":"SchwabAuthError"` | 回 [Step 3](step-3-first-oauth.md) 重跑 OAuth |
| 看到 `"error":"SchwabValidationError"` | 检查 `verify_token.py` 是否被改坏；symbol 必须 UPPERCASE |

## 不要做的事

- **不要** 把 `verify_token.py` 改成跑 50 个 symbol — 第一次跑应当是最
  小可用样本。等确认全链路通了再做批量。
- **不要** 把 stdout 直接 `tee` 到一个公开文件 — 报价含敏感时间戳，
  Schwab Market Data 是 non-redistributable。

## 下一步

→ [Step 6: Cursor / Claude integration](step-6-cursor-integration.md)

## 参考

- 多语言 MCP client 集成：[`../integration/python-mcp-client.md`](../integration/python-mcp-client.md)、[`../integration/typescript-mcp-client.md`](../integration/typescript-mcp-client.md)、[`../integration/rust-mcp-client.md`](../integration/rust-mcp-client.md)、[`../integration/cli-jq-pipe.md`](../integration/cli-jq-pipe.md)
- 12 个 tool 完整 schema：[`../tools/index.md`](../tools/index.md)
