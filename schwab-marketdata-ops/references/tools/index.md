# Tool reference — index

> All 13 outward-facing tools are `async`.  All inputs are validated by
> Pydantic before any network call.  All outputs are JSON dicts.  Errors
> are returned **as dicts** (`{"error": "Schwab…Error", …}`) — they are
> *not* raised back through the MCP protocol.

按 tool family 拆分到子文件，便于按场景定位：

| Family | File | Tools | 何时读 |
| ------ | ---- | ----- | ------ |
| Quotes | [`tool-reference-quotes.md`](tool-reference-quotes.md) | `get_quote` / `get_quotes` | 单点或批量行情 |
| Price history | [`tool-reference-price-history.md`](tool-reference-price-history.md) | `get_price_history` | OHLC / K 线，需要查 cartesian-product 合法组合 |
| Options | [`tool-reference-options.md`](tool-reference-options.md) | `get_option_chain` / `get_option_expiration_chain` | 期权链、到期日 |
| Markets | [`tool-reference-markets.md`](tool-reference-markets.md) | `get_market_hours` / `get_market_hour_single` | 多市场或单市场开闭市状态 |
| Movers | [`tool-reference-movers.md`](tool-reference-movers.md) | `get_movers` | 当日 top movers |
| Instruments | [`tool-reference-instruments.md`](tool-reference-instruments.md) | `search_instruments` / `get_instrument_by_cusip` | 模糊查找或 CUSIP 精确查找 |
| Meta | [`tool-reference-meta.md`](tool-reference-meta.md) | `health_check` / `get_server_info` | 健康巡检与版本握手 |
| Streaming 🧪 | [`tool-reference-streaming.md`](tool-reference-streaming.md) | `get_streaming_snapshot` | 准实时 bid/ask/last 或 1 分钟 K 线（实验性） |

## 跨 tool 公约

1. **symbol 大小写**：所有 tool 的 `symbol` / `symbols` 参数必须 UPPERCASE。
   传 `"aapl"` 会立即被 Pydantic 拦下，返回
   `SchwabValidationError(field="symbol")`。
2. **enum 值必须用名字**：例如 `MoversIndex.DJI` = `"DJI"`，不是
   `"$DJI"`。MCP server 内部翻译成 schwab-py 的 wire 值。
3. **批量上限 50**：`get_quotes` / `search_instruments` 单次最多 50 个
   symbol；超出立即被 Pydantic 拦下。
4. **TZ-aware datetime**：所有时间参数（`from_date` / `to_date` /
   `start_datetime` / `end_datetime` / `date`）必须带时区信息（`+00:00`
   或 `-04:00` 等），且不在未来。
5. **错误是 dict**：所有 tool 失败时**返回** `{"error": "...", ...}`，
   不抛异常穿透 MCP 协议。永远先查 `error` 字段再读 payload。
6. **stdout 不含 secret**：MCP server 在全局过滤层面 mask 任何
   `Bearer ...` / `Authorization` header；agent 也应再做一道兜底 mask。

## 不要做的事

- **不要** 在 agent 侧用正则二次验证 symbol —— server 已经做了。
- **不要** 把 enum 的 wire 值（`"$DJI"`、`"day"`）直接传进来。
- **不要** 把 OSI option symbol 传进 `get_option_chain` —— OSI 只走
  `get_quote` / `get_quotes`。

## 下一级阅读

- 错误分流：[`../error-recovery.md`](../error-recovery.md)
- 输入验证错误处置：[`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
- 限流处置：[`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
