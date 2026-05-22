# Tool reference — Quotes family

`get_quote` / `get_quotes` — 单点与批量行情。

## 1. `get_quote(symbol, fields?)`

Fetch a single quote.

| Param   | Type / values                                                                                          |
| ------- | ------------------------------------------------------------------------------------------------------ |
| symbol  | UPPERCASE str：stock/ETF (`AAPL`, `BRK.B`, `BF/B`)；index (`$SPX`, `$DJI`)；OSI option (21 chars)        |
| fields  | `list[QuoteFields]` ∈ `{"QUOTE", "FUNDAMENTAL", "EXTENDED", "REFERENCE", "REGULAR"}`                    |

### 调用示例

```text
get_quote(symbol="AAPL", fields=["QUOTE", "FUNDAMENTAL"])
get_quote(symbol="$SPX")                                # 指数
get_quote(symbol="BRK.B")                               # 含点
get_quote(symbol="BF/B")                                # 含斜杠
get_quote(symbol="AAPL  240119C00170000")               # OSI option
```

### 返回 schema（节选）

```text
{
  "symbol": "AAPL",
  "quote": { "lastPrice": ..., "bidPrice": ..., "askPrice": ..., "totalVolume": ..., ... },
  "fundamental": { ... },        # 仅 fields 含 "FUNDAMENTAL" 时有
  "regular": { "regularMarketLastPrice": ..., "regularMarketLastSize": ..., ... },
  "reference": { "exchange": "NASDAQ", "exchangeName": "NASD", ... },
  "extended": { "extendedMarketLastPrice": ..., ... }
}
```

### 常见错误

| `error`                                            | 原因                                       |
| -------------------------------------------------- | ------------------------------------------ |
| `SchwabValidationError(field="symbol")`            | 小写、含非法字符、把指数当股票（缺 `$`） |
| `SchwabAuthError`                                  | token 过期；详见 troubleshooting/auth-*    |
| `SchwabRateLimitError`                             | 触发本机或服务端限流                       |

## 2. `get_quotes(symbols, fields?, indicative?)`

Batch quotes; **max 50 symbols per call** —— 超过自行分批，否则
`SchwabValidationError(field="symbols", message="max length 50")`。

| Param        | Type / values                                                |
| ------------ | ------------------------------------------------------------ |
| symbols      | `list[str]`，长度 1-50                                        |
| fields       | 同 `get_quote`                                                |
| indicative   | `bool`，是否返回 indicative quote（仅特定品类有意义）          |

### 调用示例

```text
get_quotes(symbols=["AAPL", "MSFT", "GOOGL"], fields=["QUOTE"])
```

### 返回 schema（节选）

```text
{
  "AAPL": { "symbol": "AAPL", "quote": { ... }, ... },
  "MSFT": { "symbol": "MSFT", "quote": { ... }, ... },
  ...
}
```

如果某个 symbol 服务端找不到，会以 `null` 或缺位形式出现在 dict 里 ——
agent 务必判断每个 key 是否存在再读 `quote`。

### 自行分批的标准模板

```python
def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

results = {}
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch, fields=["QUOTE"])
    results.update(page)
```

## 何时用哪一个？

| 场景                            | 用                  |
| ------------------------------- | ------------------- |
| 1 个 symbol                     | `get_quote`         |
| 2-50 个 symbol（同质化字段）   | `get_quotes`        |
| > 50 个 symbol                  | 自行分批 `get_quotes` |
| 期权合约（OSI 21 字符）         | `get_quote`（`get_quotes` 也支持，但不要混 stock + option 在一批里以减少返回字段不一致） |

## 不要做的事

- **不要** 在 agent 侧 retry `SchwabValidationError` —— 修正参数才有意义。
- **不要** 在 agent 侧 retry `SchwabAuthError` —— 必须人介入走 OAuth。
- **不要** 把 50 个 symbol 当成必然 1 个 slot —— 服务端有可能拆开计费。

## 参考

- 输入验证错误：[`../troubleshooting/validation-symbol.md`](../troubleshooting/validation-symbol.md)
- 限流处置：[`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- OSI 期权 symbol 详解：[`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
