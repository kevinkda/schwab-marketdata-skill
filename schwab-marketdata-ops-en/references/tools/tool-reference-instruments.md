# Tool reference — Instruments family

`search_instruments` / `get_instrument_by_cusip` — fuzzy lookup and
exact lookup.

## 1. `search_instruments(symbols, projection)`

Fuzzy lookup of instrument metadata by ticker or description.

| Param      | Type / values                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| symbols    | `list[str]`, length 1-50                                                                                     |
| projection | `SYMBOL_SEARCH` / `SYMBOL_REGEX` / `DESCRIPTION_SEARCH` / `DESCRIPTION_REGEX` / `SEARCH` / `FUNDAMENTAL`     |

### Which projection to choose?

| User intent                                  | Use                       |
| -------------------------------------------- | ------------------------- |
| Exact ticker → metadata                      | `SYMBOL_SEARCH`           |
| Wildcard ticker (with `*` `?`)               | `SYMBOL_REGEX`            |
| Substring company-name lookup                | `DESCRIPTION_SEARCH`      |
| Regex company-name lookup                    | `DESCRIPTION_REGEX`       |
| Combined lookup (symbol or description)      | `SEARCH`                  |
| Detailed fundamentals (earnings, market cap) | `FUNDAMENTAL`             |

### Examples

```text
# Exact metadata for AAPL
search_instruments(symbols=["AAPL"], projection="SYMBOL_SEARCH")

# Wildcard lookup for all BRK.* (treats . literally; for regex use SYMBOL_REGEX)
search_instruments(symbols=["BRK*"], projection="SYMBOL_REGEX")

# Fuzzy lookup of company names containing "tesla"
search_instruments(symbols=["TESLA"], projection="DESCRIPTION_SEARCH")

# Pull AAPL detailed fundamentals
search_instruments(symbols=["AAPL"], projection="FUNDAMENTAL")
```

### Return schema (excerpt)

```text
{
  "instruments": [
    {
      "cusip": "037833100",
      "symbol": "AAPL",
      "description": "APPLE INC",
      "exchange": "NASDAQ",
      "assetType": "EQUITY",
      "fundamental": {                     # only when projection="FUNDAMENTAL"
        "high52": ...,
        "low52": ...,
        "dividendAmount": ...,
        "peRatio": ...,
        ...
      }
    },
    ...
  ]
}
```

## 2. `get_instrument_by_cusip(cusip)`

Exact lookup of a single instrument by 9-digit CUSIP.

| Param  | Type                                |
| ------ | ----------------------------------- |
| cusip  | exactly 9 alphanumeric characters   |

### Example

```text
get_instrument_by_cusip(cusip="037833100")   # AAPL
```

### Return schema (excerpt)

```text
{
  "instruments": [
    {
      "cusip": "037833100",
      "symbol": "AAPL",
      "description": "APPLE INC",
      ...
    }
  ]
}
```

## When to use which?

| Scenario                                  | Use                          |
| ----------------------------------------- | ---------------------------- |
| CUSIP known                               | `get_instrument_by_cusip`    |
| Ticker known                              | `search_instruments(SYMBOL_SEARCH)` |
| Partial company name known                | `search_instruments(DESCRIPTION_SEARCH)` |
| Need fundamentals                         | `search_instruments(FUNDAMENTAL)` |

## CUSIP vs. ISIN

CUSIP is the 9-digit US security identifier; ISIN is the 12-digit
international identifier (country prefix `US` + 9-digit CUSIP + 1
check digit). Schwab only accepts CUSIP. To convert ISIN → CUSIP,
take characters 3-11 (US ISINs only).

```python
def isin_to_cusip(isin: str) -> str:
    assert isin.startswith("US") and len(isin) == 12
    return isin[2:11]
```

## Common errors

| `error`                                          | Cause                                                |
| ------------------------------------------------ | ---------------------------------------------------- |
| `SchwabValidationError(field="cusip")`           | Not 9 alphanumeric characters                         |
| `SchwabValidationError(field="symbols")`        | Length 0 or > 50; contains lowercase or illegal chars |
| `SchwabValidationError(field="projection")`     | Misspelled; see the table above                       |
| `instruments == []`                             | No match found; try the `SEARCH` projection to broaden |

## What not to do

- **Do not** treat `search_instruments` as a quote tool — it returns
  metadata and fundamentals, not real-time prices. Use `get_quote` /
  `get_quotes` for prices.
- **Do not** mix tickers and CUSIPs in a single batch —
  `search_instruments` does not recognize CUSIPs; CUSIPs go through
  `get_instrument_by_cusip`.

## References

- Quotes: [`tool-reference-quotes.md`](tool-reference-quotes.md)
- Validation-error handling: [`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
