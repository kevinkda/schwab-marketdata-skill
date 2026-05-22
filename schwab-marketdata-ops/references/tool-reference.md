# Tool reference — 12 outward-facing tools

> All tools are `async`.  All inputs are validated by Pydantic before any
> network call.  All outputs are JSON dicts.  Errors are returned **as
> dicts** (`{"error": "Schwab…Error", …}`) — they are *not* raised back
> through the MCP protocol.

## 1. `get_quote(symbol, fields?)`

Fetch a single quote.

| Param   | Type / values                                                                                          |
| ------- | ------------------------------------------------------------------------------------------------------ |
| symbol  | UPPERCASE str matching one of: stock/ETF (`AAPL`, `BRK.B`, `BF/B`); index (`$SPX`, `$DJI`); OSI option (21 chars) |
| fields  | `list[QuoteFields]` ∈ `{"QUOTE", "FUNDAMENTAL", "EXTENDED", "REFERENCE", "REGULAR"}`                    |

```text
get_quote(symbol="AAPL", fields=["QUOTE", "FUNDAMENTAL"])
```

## 2. `get_quotes(symbols, fields?, indicative?)`

Batch quotes; **max 50 symbols per call** (split larger requests yourself).

```text
get_quotes(symbols=["AAPL", "MSFT", "GOOGL"], fields=["QUOTE"])
```

## 3. `get_price_history(symbol, period_type, period?, frequency_type, frequency?, …)`

Schwab silently 400s on illegal `(period_type, period, frequency_type, frequency)`
combinations.  This tool rejects them up-front:

| period_type    | legal `period`                                            | legal `frequency_type`        | legal `frequency`                          |
| -------------- | --------------------------------------------------------- | ----------------------------- | ------------------------------------------ |
| `DAY`          | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `FOUR_DAYS` / `FIVE_DAYS` / `TEN_DAYS` | `MINUTE`                | `EVERY_MINUTE` / `EVERY_FIVE_MINUTES` / `EVERY_TEN_MINUTES` / `EVERY_FIFTEEN_MINUTES` / `EVERY_THIRTY_MINUTES` |
| `MONTH`        | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `SIX_MONTHS`      | `DAILY` / `WEEKLY`            | (none — leave unset)                       |
| `YEAR`         | `FIFTEEN_YEARS` / `TWENTY_YEARS`                          | `DAILY` / `WEEKLY` / `MONTHLY` | (none)                                    |
| `YEAR_TO_DATE` | (omit)                                                    | `DAILY` / `WEEKLY`            | (none)                                    |

`start_datetime` / `end_datetime` must be **timezone-aware** (`+00:00`,
`-04:00`, etc.) and **not in the future**.

## 4. `get_option_chain(symbol, contract_type?, strike_count?, …)`

| Param                  | Type                                                                  |
| ---------------------- | --------------------------------------------------------------------- |
| symbol                 | Stock/ETF (no index, no option)                                       |
| contract_type          | `"CALL"` / `"PUT"` / `"ALL"`                                          |
| strike_count           | int 1-500                                                             |
| include_underlying_quote | bool                                                                |
| strategy               | `SINGLE` / `ANALYTICAL` / `COVERED` / `VERTICAL` / `CALENDAR` / `STRANGLE` / `STRADDLE` / `BUTTERFLY` / `CONDOR` / `DIAGONAL` / `COLLAR` / `ROLL` |
| interval, strike       | float > 0                                                             |
| strike_range           | `IN_THE_MONEY` / `NEAR_THE_MONEY` / `OUT_OF_THE_MONEY` / `STRIKES_ABOVE_MARKET` / `STRIKES_BELOW_MARKET` / `STRIKES_NEAR_MARKET` / `ALL` |
| from_date, to_date     | TZ-aware datetime; `to_date >= from_date`                             |
| volatility, underlying_price, interest_rate | float                                            |
| days_to_expiration     | int 0-3650                                                            |
| exp_month              | `JANUARY` … `DECEMBER` / `ALL`                                        |
| option_type            | `STANDARD` / `NON_STANDARD` / `ALL`                                   |
| entitlement            | `PAYING_PRO` / `NON_PRO` / `NON_PAYING_PRO`                           |

## 5. `get_option_expiration_chain(symbol)`

Returns the available option expiration dates.  No other params.

## 6. `get_market_hours(markets_list, date?)`

`markets_list`: 1–5 of `{"EQUITY", "OPTION", "BOND", "FUTURE", "FOREX"}`.

## 7. `get_market_hour_single(market_id, date?)`

`market_id`: one of the 5 above.

## 8. `get_movers(index, sort_order?, frequency?)`

| Param      | Values                                                                                  |
| ---------- | --------------------------------------------------------------------------------------- |
| index      | `DJI` / `COMPX` / `SPX` / `NYSE` / `NASDAQ` / `OTCBB` / `INDEX_ALL` / `EQUITY_ALL` / `OPTION_ALL` / `OPTION_PUT` / `OPTION_CALL` |
| sort_order | `VOLUME` / `TRADES` / `PERCENT_CHANGE_UP` / `PERCENT_CHANGE_DOWN`                       |
| frequency  | `ZERO` / `ONE` / `FIVE` / `TEN` / `THIRTY` / `SIXTY`                                    |

## 9. `search_instruments(symbols, projection)`

| Param      | Values                                                                                            |
| ---------- | ------------------------------------------------------------------------------------------------- |
| symbols    | list[stock-style symbol]; up to 50                                                                |
| projection | `SYMBOL_SEARCH` / `SYMBOL_REGEX` / `DESCRIPTION_SEARCH` / `DESCRIPTION_REGEX` / `SEARCH` / `FUNDAMENTAL` |

## 10. `get_instrument_by_cusip(cusip)`

`cusip`: exactly 9 alphanumeric characters.

## 11. `health_check()`

```text
{
  "server_version": "0.1.x",
  "token_state": "valid"|"missing"|"malformed"|"insecure_perms",
  "token_age_days": float | null,
  "token_expires_in_days": float | null,
  "last_request_status": "unknown",
  "rate_limit_remaining_per_min": int,
  "recent_error_count_24h": int,
  "platform_supported": true
}
```

## 12. `get_server_info()`

```text
{
  "server_version": "0.1.x",
  "mcp_sdk_version": "...",
  "schwab_py_version": "1.5.1",
  "supported_tools": [...12 names...],
  "platform_supported_v1": ["macos>=11", "linux"]
}
```
