# Tool reference — Options family

`get_option_chain` / `get_option_expiration_chain` — option chains and
expiration lists.

## 1. `get_option_expiration_chain(symbol)`

Returns every available option expiration for a given symbol. **Call
this first**, then call `get_option_chain` to narrow strike range /
expiration range — avoids pulling the entire chain at once.

| Param  | Type                                                    |
| ------ | ------------------------------------------------------- |
| symbol | UPPERCASE str; stock/ETF (**does not accept** index or OSI) |

### Example

```text
get_option_expiration_chain(symbol="AAPL")
```

### Return schema (excerpt)

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

`expirationType`: `M` = monthly, `W` = weekly, `Q` = quarterly.

## 2. `get_option_chain(symbol, contract_type?, strike_count?, …)`

Pull concrete contracts by ATM/OTM/ITM.

| Param                        | Type / values                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------------- |
| symbol                       | UPPERCASE stock/ETF (**does not accept** index or OSI)                                            |
| contract_type                | `"CALL"` / `"PUT"` / `"ALL"`                                                                      |
| strike_count                 | int 1-500                                                                                         |
| include_underlying_quote     | bool                                                                                              |
| strategy                     | `SINGLE` / `ANALYTICAL` / `COVERED` / `VERTICAL` / `CALENDAR` / `STRANGLE` / `STRADDLE` / `BUTTERFLY` / `CONDOR` / `DIAGONAL` / `COLLAR` / `ROLL` |
| interval, strike             | float > 0                                                                                         |
| strike_range                 | `IN_THE_MONEY` / `NEAR_THE_MONEY` / `OUT_OF_THE_MONEY` / `STRIKES_ABOVE_MARKET` / `STRIKES_BELOW_MARKET` / `STRIKES_NEAR_MARKET` / `ALL` |
| from_date, to_date           | TZ-aware datetime; `to_date >= from_date`                                                         |
| volatility, underlying_price, interest_rate | float                                                                              |
| days_to_expiration           | int 0-3650                                                                                        |
| exp_month                    | `JANUARY` … `DECEMBER` / `ALL`                                                                    |
| option_type                  | `STANDARD` / `NON_STANDARD` / `ALL`                                                               |
| entitlement                  | `PAYING_PRO` / `NON_PRO` / `NON_PAYING_PRO`                                                       |

### Recommended query templates

```text
# 1) Find the nearest-month ATM ±10 strikes (the most common view)
get_option_chain(
    symbol="AAPL",
    contract_type="ALL",
    strike_count=10,
    strike_range="NEAR_THE_MONEY",
    days_to_expiration=30,
)
```

```text
# 2) All ATM ±5 calls for one specific expiry
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
# 3) Vertical spread (the strategy lets the server pre-compute spread pricing)
get_option_chain(
    symbol="AAPL",
    contract_type="CALL",
    strategy="VERTICAL",
    interval=5.0,
    strike=170.0,
)
```

## Return schema (excerpt)

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
  "putExpDateMap": { ... },          # symmetric structure
  "interval": 0.0,
  "isDelayed": false,
  "isIndex": false,
  "interestRate": ...,
  "underlyingPrice": ...,
  "volatility": 0.0,
  "daysToExpiration": 0
}
```

The `callExpDateMap` key is formatted as `"<YYYY-MM-DD>:<DTE>"`; the
second-level key is the strike (a stringified float).

## Greeks freshness

`delta` / `gamma` / `theta` / `vega` are **snapshots** computed by the
Schwab server from the latest order book and implied volatility — not a
live continuously-updated stream. Repeated calls with the same
parameters in a short interval will show small drift in the Greeks —
this is expected. For serious pricing work, compute them yourself
(use `volatility` + `underlyingPrice` + `interestRate` and the
Black-Scholes formula).

## Common errors

| `error`                                          | Cause                                                  |
| ------------------------------------------------ | ------------------------------------------------------ |
| `SchwabValidationError(field="symbol")`         | Treating an OSI or index as the underlying (only stock/ETF accepted) |
| `SchwabValidationError(field="strike_count")`   | Not in the 1-500 range                                 |
| `SchwabValidationError(field="from_date\|to_date")` | naive datetime / `to_date < from_date` / in the future |
| `status == "FAILED"` with no error              | The server cannot find the underlying; verify the symbol actually has an option chain |

## What not to do

- **Do not** pull the entire chain at once with `strike_count=500` —
  the payload is huge and easily trips rate limiting.
- **Do not** feed the OSI symbol from a previous `get_option_chain`
  back into `get_option_chain` (OSI goes through `get_quote`).

## References

- OSI option symbol deep dive: [`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- Rate-limit handling: [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- Option chain research playbook: `../../../schwab-marketdata-workflows-en/playbooks/option-chain-research.md`
