# Tool reference — Movers family

`get_movers` — today's top movers.

## Signature

```text
get_movers(
    index: MoversIndex,
    sort_order: MoversSortOrder | None = None,
    frequency: MoversFrequency | None = None,
)
```

| Param      | Values                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| index      | `DJI` / `COMPX` / `SPX` / `NYSE` / `NASDAQ` / `OTCBB` / `INDEX_ALL` / `EQUITY_ALL` / `OPTION_ALL` / `OPTION_PUT` / `OPTION_CALL` |
| sort_order | `VOLUME` / `TRADES` / `PERCENT_CHANGE_UP` / `PERCENT_CHANGE_DOWN`                                            |
| frequency  | `ZERO` / `ONE` / `FIVE` / `TEN` / `THIRTY` / `SIXTY`                                                         |

Note: every enum is the **schwab-py name used internally by the MCP
server**, not the wire value (e.g. `"DJI"` rather than `"$DJI"`).

## Examples

```text
# Dow Jones constituents sorted by volume
get_movers(index="DJI", sort_order="VOLUME")

# NASDAQ 100 biggest gainers
get_movers(index="COMPX", sort_order="PERCENT_CHANGE_UP")

# Biggest decliners (within ≥10% threshold)
get_movers(index="SPX", sort_order="PERCENT_CHANGE_DOWN", frequency="TEN")

# Full-market option call top movers
get_movers(index="OPTION_CALL", sort_order="VOLUME")
```

## Return schema (excerpt)

```text
{
  "screeners": [
    {
      "symbol": "AAPL",
      "description": "APPLE INC",
      "lastPrice": 175.10,
      "marketShare": 6.34,
      "totalVolume": 12345678,
      "trades": 56789,
      "netChange": 1.23,
      "netPercentChange": 0.71,
      "volume": 12345678
    },
    ...
  ]
}
```

## sort_order semantics

| Value                    | Sort key                | Direction |
| ------------------------ | ----------------------- | --------- |
| `VOLUME`                 | `totalVolume`           | descending |
| `TRADES`                 | `trades`                | descending |
| `PERCENT_CHANGE_UP`      | `netPercentChange`     | descending |
| `PERCENT_CHANGE_DOWN`    | `netPercentChange`     | ascending  |

## frequency semantics

| Value     | Meaning                                                     |
| --------- | ----------------------------------------------------------- |
| `ZERO`    | No minimum change threshold (default; returns all movers)   |
| `ONE`     | Only entries with ≥ 1% change                               |
| `FIVE`    | ≥ 5%                                                        |
| `TEN`     | ≥ 10%                                                       |
| `THIRTY`  | ≥ 30%                                                       |
| `SIXTY`   | ≥ 60% (extreme filter; usually only small-caps or halt-resume spikes) |

## index selection guide

| User wants                             | Use                  |
| -------------------------------------- | -------------------- |
| Dow Jones 30 constituents              | `DJI`                |
| NASDAQ 100 / Composite                 | `COMPX`              |
| S&P 500                                | `SPX`                |
| All NYSE                               | `NYSE`               |
| All NASDAQ Exchange                    | `NASDAQ`             |
| OTC (over-the-counter)                 | `OTCBB`              |
| Combined three major indices           | `INDEX_ALL`          |
| All equities (including OTC)           | `EQUITY_ALL`         |
| Options (puts + calls)                 | `OPTION_ALL`         |
| Puts only                              | `OPTION_PUT`         |
| Calls only                             | `OPTION_CALL`        |

## Common errors

| `error`                                        | Cause                                                   |
| ---------------------------------------------- | ------------------------------------------------------- |
| `SchwabValidationError(field="index")`         | Misspelled (e.g. passed `"$DJI"` instead of `"DJI"`)    |
| `SchwabValidationError(field="frequency")`    | Not in the legal enum set                                |
| `screeners == []`                             | Trading has not started today / pre-market / holiday; check the time-of-day, call `get_market_hours` first |

## What not to do

- **Do not** interpret `frequency` as a time window — it is a
  **percent-change threshold**, not a lookback duration.
- **Do not** call this in pre-market hours (`isOpen == false` and
  before 09:30 US-Eastern) — you will always get an empty list.

## References

- Multi-market status: [`tool-reference-markets.md`](tool-reference-markets.md)
- Validation-error handling: [`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
