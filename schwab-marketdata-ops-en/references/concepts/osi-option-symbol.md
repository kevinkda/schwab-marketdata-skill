# OSI option symbol

> OCC Symbology Initiative: a 21-character fixed-format option
> identifier. Schwab, most US brokers, and CBOE all use it.

## Format

```text
{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}
```

Exactly **21** characters; the root is left-aligned and right-padded
with spaces to 6 characters.

| Segment       | Length | Meaning                                                |
| ------------- | ------ | ------------------------------------------------------ |
| ROOT          | 6      | Underlying ticker, left-aligned, right-padded with spaces |
| YYMMDD        | 6      | Expiration date (year + month + day, 2 + 2 + 2 digits) |
| C / P         | 1      | `C` = Call, `P` = Put                                  |
| STRIKE×1000   | 8      | strike × 1000, 8-digit integer (zero-padded)           |

## Full examples

| OSI symbol               | Decoded                                       |
| ------------------------ | --------------------------------------------- |
| `AAPL  240119C00170000`  | AAPL 2024-01-19 Call $170.00                  |
| `BRK/B 240419P00350000`  | BRK/B 2024-04-19 Put $350.00                  |
| `SPY   251219C00500000`  | SPY 2025-12-19 Call $500.00 (note 3 spaces)   |
| `BF/B  240517P00040000`  | BF/B 2024-05-17 Put $40.00                    |
| `AMZN  240920C00150500`  | AMZN 2024-09-20 Call $150.50                  |
| `TSLA  240105C00700000`  | TSLA 2024-01-05 Call $700.00                  |

## Encoder utilities

### Python

```python
def build_osi(root: str, expiry_yymmdd: str, c_or_p: str, strike_dollars: float) -> str:
    """
    >>> build_osi("AAPL", "240119", "C", 170.0)
    'AAPL  240119C00170000'
    >>> build_osi("BRK/B", "240419", "P", 350.0)
    'BRK/B 240419P00350000'
    >>> build_osi("AMZN", "240920", "C", 150.50)
    'AMZN  240920C00150500'
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

### TypeScript

```typescript
export function buildOsi(
    root: string,
    expiryYymmdd: string,
    cOrP: "C" | "P",
    strikeDollars: number,
): string {
    if (!/^\d{6}$/.test(expiryYymmdd)) {
        throw new Error(`expiry must be YYMMDD, got ${expiryYymmdd}`);
    }
    if (!(strikeDollars > 0 && strikeDollars < 100000)) {
        throw new Error(`strike out of range: ${strikeDollars}`);
    }
    const strikeInt = Math.round(strikeDollars * 1000);
    return (
        root.toUpperCase().padEnd(6, " ") +
        expiryYymmdd +
        cOrP +
        strikeInt.toString().padStart(8, "0")
    );
}

// buildOsi("AAPL", "240119", "C", 170.0) => "AAPL  240119C00170000"
// buildOsi("BRK/B", "240419", "P", 350.0) => "BRK/B 240419P00350000"
```

### Rust

```rust
pub fn build_osi(root: &str, expiry_yymmdd: &str, c_or_p: char, strike_dollars: f64) -> String {
    assert!(matches!(c_or_p, 'C' | 'P'));
    assert_eq!(expiry_yymmdd.len(), 6);
    assert!(expiry_yymmdd.chars().all(|c| c.is_ascii_digit()));
    assert!(strike_dollars > 0.0 && strike_dollars < 100_000.0);

    let strike_int = (strike_dollars * 1000.0).round() as u32;
    format!("{:<6}{}{}{:08}", root.to_uppercase(), expiry_yymmdd, c_or_p, strike_int)
}
```

## Decoding

```python
import re

OSI_RE = re.compile(r"^(.{6})(\d{6})([CP])(\d{8})$")

def parse_osi(symbol: str) -> dict:
    """
    >>> parse_osi("AAPL  240119C00170000")
    {'root': 'AAPL', 'expiry': '240119', 'cp': 'C', 'strike': 170.0}
    """
    if len(symbol) != 21:
        raise ValueError(f"OSI must be exactly 21 chars, got {len(symbol)}")
    m = OSI_RE.match(symbol)
    if not m:
        raise ValueError(f"invalid OSI: {symbol!r}")
    root, exp, cp, strike_str = m.groups()
    return {
        "root": root.strip(),
        "expiry": exp,
        "cp": cp,
        "strike": int(strike_str) / 1000.0,
    }
```

## 4 common input errors

| Bad form                          | Length | Fix                                  |
| --------------------------------- | ------ | ------------------------------------ |
| `"AAPL240119C00170000"`           | 19     | Missing space-padding → `"AAPL  240119C00170000"` |
| `"AAPL  2024-01-19C00170000"`     | 25     | Contains hyphens → `"AAPL  240119C00170000"` |
| `"AAPL  240119X00170000"`         | 21     | Wrong C/P field → must be `C` or `P` |
| `"AAPL  240119C00170"`            | 18     | Strike missing leading zeros → `"AAPL  240119C00170000"` |

## How to use it in schwab-mcp

OSI symbols are passed directly to `get_quote` / `get_quotes`:

```text
get_quote(symbol="AAPL  240119C00170000")
get_quotes(symbols=["AAPL  240119C00170000", "AAPL  240119P00170000"])
```

The return schema includes option-specific fields (`delta` /
`gamma` / `theta` / `vega` / etc.).

**Do not** pass OSI to `get_option_chain` — it only accepts a
stock/ETF underlying. Instead, call `get_option_expiration_chain`
first, then `get_option_chain` to get a contract list, then use the
contract's OSI to call `get_quote`.

## What not to do

- **Do not** hand-build the string without checking length == 21.
- **Do not** pass strike as a string `"170.00"` — it must be
  `170.0` (float) and let `build_osi` compute `00170000`.
- **Do not** assume the root equals the ticker — some tickers contain
  `.` or `/`, and OSI preserves them as-is (`BRK.B` → root `BRK.B`,
  5 chars + 1 space).

## References

- Options tool reference: [`../tools/tool-reference-options.md`](../tools/tool-reference-options.md)
- Input-validation error handling: [`../troubleshooting/validation-osi-format.md`](../troubleshooting/validation-osi-format.md)
- OCC official docs: <https://en.wikipedia.org/wiki/Option_symbol>
