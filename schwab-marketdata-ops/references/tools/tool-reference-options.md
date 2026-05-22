# Tool reference — Options family

`get_option_chain` / `get_option_expiration_chain` — 期权链与到期日。

## 1. `get_option_expiration_chain(symbol)`

返回单个 symbol 的全部可用 option 到期日。**先调它**再调
`get_option_chain` 缩小 strike 范围 / 到期日范围，避免一次拉爆。

| Param  | Type                                  |
| ------ | ------------------------------------- |
| symbol | UPPERCASE str；stock/ETF（**不接受** index 或 OSI） |

### 调用示例

```text
get_option_expiration_chain(symbol="AAPL")
```

### 返回 schema（节选）

```text
{
  "symbol": "AAPL",
  "expirationList": [
    { "expirationDate": "2024-04-19", "daysToExpiration": 28, "expirationType": "M", ... },
    { "expirationDate": "2024-05-17", "daysToExpiration": 56, ... },
    ...
  ]
}
```

`expirationType`：`M` = monthly、`W` = weekly、`Q` = quarterly。

## 2. `get_option_chain(symbol, contract_type?, strike_count?, …)`

按 ATM/OTM/ITM 拉具体合约链。

| Param                        | Type / values                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------------- |
| symbol                       | UPPERCASE stock/ETF（**不接受** index 或 OSI）                                                     |
| contract_type                | `"CALL"` / `"PUT"` / `"ALL"`                                                                      |
| strike_count                 | int 1-500                                                                                         |
| include_underlying_quote     | bool                                                                                              |
| strategy                     | `SINGLE` / `ANALYTICAL` / `COVERED` / `VERTICAL` / `CALENDAR` / `STRANGLE` / `STRADDLE` / `BUTTERFLY` / `CONDOR` / `DIAGONAL` / `COLLAR` / `ROLL` |
| interval, strike             | float > 0                                                                                         |
| strike_range                 | `IN_THE_MONEY` / `NEAR_THE_MONEY` / `OUT_OF_THE_MONEY` / `STRIKES_ABOVE_MARKET` / `STRIKES_BELOW_MARKET` / `STRIKES_NEAR_MARKET` / `ALL` |
| from_date, to_date           | TZ-aware datetime；`to_date >= from_date`                                                         |
| volatility, underlying_price, interest_rate | float                                                                              |
| days_to_expiration           | int 0-3650                                                                                        |
| exp_month                    | `JANUARY` … `DECEMBER` / `ALL`                                                                    |
| option_type                  | `STANDARD` / `NON_STANDARD` / `ALL`                                                               |
| entitlement                  | `PAYING_PRO` / `NON_PRO` / `NON_PAYING_PRO`                                                       |

### 推荐查询模板

```text
# 1) 找最近月 ATM ±10 strike（最常见的视图）
get_option_chain(
    symbol="AAPL",
    contract_type="ALL",
    strike_count=10,
    strike_range="NEAR_THE_MONEY",
    days_to_expiration=30,
)
```

```text
# 2) 拉某月所有 ATM ±5 call
from datetime import datetime, timezone
get_option_chain(
    symbol="AAPL",
    contract_type="CALL",
    strike_count=5,
    strike_range="NEAR_THE_MONEY",
    from_date=datetime(2024, 4, 19, tzinfo=timezone.utc),
    to_date=datetime(2024, 4, 19, tzinfo=timezone.utc),
)
```

```text
# 3) 配 vertical spread（用 strategy 让服务端预先计算 spread 价格）
get_option_chain(
    symbol="AAPL",
    contract_type="CALL",
    strategy="VERTICAL",
    interval=5.0,
    strike=170.0,
)
```

## 返回 schema（节选）

```text
{
  "symbol": "AAPL",
  "status": "SUCCESS",
  "underlying": { "symbol": "AAPL", "last": 175.10, ... },
  "callExpDateMap": {
    "2024-04-19:28": {
      "170.0": [ { "putCall": "CALL", "symbol": "AAPL  240419C00170000", "strikePrice": 170.0, "lastPrice": ..., "delta": ..., "gamma": ..., "theta": ..., "vega": ..., ... } ],
      "175.0": [ ... ],
      ...
    }
  },
  "putExpDateMap": { ... },          # 对称结构
  "interval": 0.0,
  "isDelayed": false,
  "isIndex": false,
  "interestRate": ...,
  "underlyingPrice": ...,
  "volatility": 0.0,
  "daysToExpiration": 0
}
```

`callExpDateMap` 的 key 形如 `"<YYYY-MM-DD>:<DTE>"`，second-level key 是
strike（字符串形式的 float）。

## Greeks 时效性

`delta` / `gamma` / `theta` / `vega` 是 Schwab 服务端用最新挂单与隐含
波动率算的 **快照**，不是实时持续更新。短时间内重复调相同参数，
Greeks 字段会少量浮动 —— 这是预期行为。如要做严肃定价，自己计算
（用 `volatility` + `underlyingPrice` + `interestRate` 与 BS 公式）。

## 常见错误

| `error`                                          | 原因                                                  |
| ------------------------------------------------ | ----------------------------------------------------- |
| `SchwabValidationError(field="symbol")`         | 把 OSI 或 index 当 underlying（仅接受 stock/ETF）     |
| `SchwabValidationError(field="strike_count")`   | 不在 1-500 范围                                       |
| `SchwabValidationError(field="from_date\|to_date")` | naive datetime / `to_date < from_date` / 在未来       |
| `status == "FAILED"` 但无 error                 | 服务端找不到 underlying；检查 symbol 是否真的有期权链 |

## 不要做的事

- **不要** 一次性 `strike_count=500` 拉全链 —— 体积巨大，易撞限流。
- **不要** 把上一次 `get_option_chain` 的 OSI symbol 拿去再调
  `get_option_chain`（OSI 走 `get_quote`）。

## 参考

- OSI 期权 symbol 详解：[`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- 限流处置：[`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- 期权链研究 playbook：`../../../schwab-marketdata-workflows/playbooks/option-chain-research.md`
