# Troubleshooting — `SchwabValidationError(field="symbol")`

The symbol / symbols field fails the Pydantic regex. There are 4
common patterns.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/validation-symbol.md`](../../../schwab-marketdata-ops/references/troubleshooting/validation-symbol.md).

## Symptom

```text
{"error":"SchwabValidationError","field":"symbol","message":"...does not match…"}
{"error":"SchwabValidationError","field":"symbols","message":"..."}
```

## Root cause (4 typical patterns)

1. **Lowercase ticker** — `"aapl"`; must be UPPERCASE
2. **Illegal characters** — `"BRK.B "` (trailing space) /
   `"AAPL\t"` (contains tab)
3. **Index passed as a stock** — `"SPX"` instead of `"$SPX"`
4. **OSI option passed as a stock** — OSI strings only fit
   `get_quote/get_quotes`, not `get_option_chain`

## Diagnostic command

Cross-check against the legal-format table in
[`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md) §1.

## Fix template

```python
# get_quote("aapl") → error
# Correct usages:
get_quote("AAPL")
get_quote("$SPX")                          # index
get_quote("BRK.B")                         # ETF / contains a dot
get_quote("BF/B")                          # contains a slash
get_quote("AAPL  240119C00170000")         # OSI 21 chars (root padded with spaces)
```

## 4 legal symbol shapes

| Type           | Example                            | Regex constraint                        |
| -------------- | --------------------------------- | --------------------------------------- |
| Stock / ETF    | `AAPL` / `MSFT` / `BRK.B` / `BF/B` | `[A-Z][A-Z./]{0,9}`                     |
| Index          | `$SPX` / `$DJI` / `$COMPX`         | `\$[A-Z]{1,6}`                          |
| OSI option     | `AAPL  240119C00170000`            | `[A-Z][A-Z]{0,5} {0,5}\d{6}[CP]\d{8}`, total 21 chars |
| Forex (rare)   | `EUR/USD` / `USD/JPY`              | `[A-Z]{3}/[A-Z]{3}`                     |

## Self-check helper

```python
import re

SYMBOL_RE = re.compile(r"^[A-Z$./ ]{1,21}$")

def assert_symbol_ok(s: str) -> None:
    if not SYMBOL_RE.fullmatch(s):
        raise ValueError(f"invalid symbol shape: {s!r}")
```

Note: `s` must be `s.strip().upper()` before validation.

## Verification

After the fix, the same call no longer errors:

```python
quote = await get_quote("AAPL")
assert "error" not in quote or quote["error"] is None
```

## What not to do

- **Do not** re-implement the symbol regex on the agent side — the
  server already does it; the agent only needs to normalize (strip +
  upper).
- **Do not** pass an OSI string into `get_option_chain` — use
  `get_option_expiration_chain` to get the date list, then
  `get_option_chain`.
- **Do not** comma-join multiple symbols into a single string for
  `get_quote` — use `get_quotes(symbols=[...])` with a list.

## References

- Quotes tool reference: [`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md)
- OSI deep dive: [`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- Validation overview: [`validation-overview.md`](validation-overview.md)
