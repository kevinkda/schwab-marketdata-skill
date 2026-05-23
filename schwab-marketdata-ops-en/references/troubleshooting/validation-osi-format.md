# Troubleshooting — OSI option symbol format error

An OSI option symbol must be **exactly 21 characters**; otherwise
Pydantic rejects it.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/validation-osi-format.md`](../../../schwab-marketdata-ops/references/troubleshooting/validation-osi-format.md).

## Symptom

```text
{"error":"SchwabValidationError","field":"symbol","message":"invalid OSI format"}
```

## 4 typical violations

| Wrong form                          | Length | Fix                                          |
| ----------------------------------- | ------ | -------------------------------------------- |
| `"AAPL240119C00170000"`             | 19     | Root shorter than 6 chars without space-padding → `"AAPL  240119C00170000"` |
| `"AAPL  2024-01-19C00170000"`       | 25     | Date is not `YYMMDD` → `"AAPL  240119C00170000"` |
| `"AAPL  240119X00170000"`           | 21     | C/P field is neither `C` nor `P` → use `C` or `P` |
| `"AAPL  240119C00170"`              | 18     | Strike is not 8 digits → `"AAPL  240119C00170000"` |

## Diagnostic snippet

```python
symbol = "AAPL  240119C00170000"
assert len(symbol) == 21, f"OSI must be 21 chars, got {len(symbol)}"
assert symbol[6:12].isdigit(), "YYMMDD must be 6 digits"
assert symbol[12] in ("C", "P"), "char 13 must be C or P"
assert symbol[13:].isdigit() and len(symbol[13:]) == 8, "strike must be 8 digits"
```

## Fix template

```python
def build_osi(root: str, expiry_yymmdd: str, c_or_p: str, strike_dollars: float) -> str:
    """
    >>> build_osi("AAPL", "240119", "C", 170.0)
    'AAPL  240119C00170000'
    >>> build_osi("BRK/B", "240419", "P", 350.0)
    'BRK/B 240419P00350000'
    """
    if c_or_p not in ("C", "P"):
        raise ValueError(f"c_or_p must be 'C' or 'P', got {c_or_p}")
    if len(expiry_yymmdd) != 6 or not expiry_yymmdd.isdigit():
        raise ValueError(f"expiry must be YYMMDD, got {expiry_yymmdd}")
    if not (0 < strike_dollars < 100_000):
        raise ValueError(f"strike out of range: {strike_dollars}")
    strike_int = int(round(strike_dollars * 1000))
    return f"{root.upper():<6}{expiry_yymmdd}{c_or_p}{strike_int:08d}"
```

## Verification

```python
osi = build_osi("AAPL", "240119", "C", 170.0)
assert len(osi) == 21
quote = await get_quote(symbol=osi)
assert "error" not in quote or quote["error"] is None
# Includes option-specific fields
assert "delta" in quote.get("quote", {}) or "delta" in quote.get("option", {})
```

## Examples for various root lengths

| Root  | Root segment (6 chars)   | Full OSI example              |
| ----- | ------------------------ | ----------------------------- |
| AAPL  | `"AAPL  "` (4 + 2 spaces) | `AAPL  240119C00170000`       |
| BRK/B | `"BRK/B "` (5 + 1 space)  | `BRK/B 240419P00350000`       |
| SPY   | `"SPY   "` (3 + 3 spaces) | `SPY   251219C00500000`       |
| AMZN  | `"AMZN  "` (4 + 2 spaces) | `AMZN  240920C00150500`       |
| BF/B  | `"BF/B  "` (4 + 2 spaces) | `BF/B  240517P00040000`       |

## What not to do

- **Do not** re-implement OSI regex validation on the agent side —
  the server already does it; just use the `build_osi` helper.
- **Do not** pass an OSI into `get_option_chain` — that endpoint
  only accepts a stock/ETF root.
- **Do not** assume the root segment is always the ticker — tickers
  containing `.` or `/` are kept as-is.

## References

- OSI deep dive: [`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- Options tool reference: [`../tools/tool-reference-options.md`](../tools/tool-reference-options.md)
- Validation overview: [`validation-overview.md`](validation-overview.md)
