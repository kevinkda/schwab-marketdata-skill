# Tool reference — Quotes family

`get_quote` / `get_quotes` — single and batched quotes.

## 1. `get_quote(symbol, fields?)`

Fetch a single quote.

| Param   | Type / values                                                                                          |
| ------- | ------------------------------------------------------------------------------------------------------ |
| symbol  | UPPERCASE str: stock/ETF (`AAPL`, `BRK.B`, `BF/B`); index (`$SPX`, `$DJI`); OSI option (21 chars)       |
| fields  | `list[QuoteFields]` ∈ `{"QUOTE", "FUNDAMENTAL", "EXTENDED", "REFERENCE", "REGULAR"}`                    |

### Examples

```text
get_quote(symbol="AAPL", fields=["QUOTE", "FUNDAMENTAL"])
get_quote(symbol="$SPX")                                # index
get_quote(symbol="BRK.B")                               # contains a dot
get_quote(symbol="BF/B")                                # contains a slash
get_quote(symbol="AAPL  240119C00170000")               # OSI option
```

### Return schema (excerpt)

```text
{
  "symbol": "AAPL",
  "quote": { "lastPrice": ..., "bidPrice": ..., "askPrice": ..., "totalVolume": ..., ... },
  "fundamental": { ... },        # only present if fields contained "FUNDAMENTAL"
  "regular": { "regularMarketLastPrice": ..., "regularMarketLastSize": ..., ... },
  "reference": { "exchange": "NASDAQ", "exchangeName": "NASD", ... },
  "extended": { "extendedMarketLastPrice": ..., ... }
}
```

### Common errors

| `error`                                            | Cause                                                |
| -------------------------------------------------- | ---------------------------------------------------- |
| `SchwabValidationError(field="symbol")`            | lowercase, illegal characters, treating an index as a stock (missing `$`) |
| `SchwabAuthError`                                  | token expired; see troubleshooting/auth-*            |
| `SchwabRateLimitError`                             | hit local or server-side rate limit                  |

## 2. `get_quotes(symbols, fields?, indicative?)`

Batched quotes; **max 50 symbols per call** — chunk on the client side
when over 50, otherwise
`SchwabValidationError(field="symbols", message="max length 50")`.

| Param        | Type / values                                                |
| ------------ | ------------------------------------------------------------ |
| symbols      | `list[str]`, length 1-50                                     |
| fields       | same as `get_quote`                                          |
| indicative   | `bool`; return indicative quote (only meaningful for certain instrument types) |

### Examples

```text
get_quotes(symbols=["AAPL", "MSFT", "GOOGL"], fields=["QUOTE"])
```

### Return schema (excerpt)

```text
{
  "AAPL": { "symbol": "AAPL", "quote": { ... }, ... },
  "MSFT": { "symbol": "MSFT", "quote": { ... }, ... },
  ...
}
```

If a symbol cannot be found server-side, it appears in the dict as
`null` or is omitted entirely — the agent must check whether each key
exists before reading `quote`.

### Standard chunking template

```python
def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

results = {}
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch, fields=["QUOTE"])
    results.update(page)
```

## When to use which?

| Scenario                          | Use                  |
| --------------------------------- | -------------------- |
| 1 symbol                          | `get_quote`          |
| 2-50 symbols (homogeneous fields) | `get_quotes`         |
| > 50 symbols                      | client-side chunked `get_quotes` |
| Option contract (21-char OSI)     | `get_quote` (`get_quotes` works too, but do not mix stock + option in the same batch — return-field shapes differ) |

## What not to do

- **Do not** retry `SchwabValidationError` on the agent side — fixing
  the argument is the only sensible response.
- **Do not** retry `SchwabAuthError` on the agent side — a human must
  re-run OAuth.
- **Do not** assume 50 symbols always counts as 1 slot — the server may
  bill per symbol.

## References

- Input-validation errors: [`../troubleshooting/validation-symbol.md`](../troubleshooting/validation-symbol.md)
- Rate-limit handling: [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- OSI option symbol deep dive: [`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
