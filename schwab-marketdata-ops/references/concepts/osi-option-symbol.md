# OSI option symbol

> OCC Symbology Initiative：21 字符固定格式 option 标识符。Schwab、
> 多数美国 broker、CBOE 都用它。

## 格式

```text
{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}
```

精确 **21** 字符，左对齐 root，空格右补齐到 6 字符。

| 段           | 长度 | 含义                                     |
| ------------ | ---- | ---------------------------------------- |
| ROOT         | 6    | underlying ticker，左对齐空格右补齐      |
| YYMMDD       | 6    | 到期日（年月日，2 位 + 2 位 + 2 位数字）   |
| C / P        | 1    | `C` = Call，`P` = Put                    |
| STRIKE×1000 | 8    | strike × 1000，8 位整数（前导零）          |

## 完整示例

| OSI symbol               | 解读                                  |
| ------------------------ | ------------------------------------- |
| `AAPL  240119C00170000`  | AAPL 2024-01-19 Call $170.00          |
| `BRK/B 240419P00350000`  | BRK/B 2024-04-19 Put $350.00          |
| `SPY   251219C00500000`  | SPY 2025-12-19 Call $500.00（注意 3 空格） |
| `BF/B  240517P00040000`  | BF/B 2024-05-17 Put $40.00            |
| `AMZN  240920C00150500`  | AMZN 2024-09-20 Call $150.50          |
| `TSLA  240105C00700000`  | TSLA 2024-01-05 Call $700.00          |

## 编码工具函数

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

## 解码

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

## 4 种常见输入错误

| 错误形式                          | 长度 | 修复                                |
| --------------------------------- | ---- | ----------------------------------- |
| `"AAPL240119C00170000"`           | 19   | 漏空格右补齐 → `"AAPL  240119C00170000"` |
| `"AAPL  2024-01-19C00170000"`     | 25   | 含连字符 → `"AAPL  240119C00170000"` |
| `"AAPL  240119X00170000"`         | 21   | C/P 字段错 → `C` 或 `P`             |
| `"AAPL  240119C00170"`            | 18   | strike 漏前导零 → `"AAPL  240119C00170000"` |

## 在 schwab-mcp 中如何使用

OSI symbol 直接传给 `get_quote` / `get_quotes`：

```text
get_quote(symbol="AAPL  240119C00170000")
get_quotes(symbols=["AAPL  240119C00170000", "AAPL  240119P00170000"])
```

返回 schema 含 option-specific 字段（`delta` / `gamma` / `theta` / `vega`
等）。

**不要**把 OSI 传给 `get_option_chain` —— 后者只接受 stock/ETF
underlying，应当先 `get_option_expiration_chain` 再 `get_option_chain`
拿到合约列表，再用合约的 OSI 调 `get_quote`。

## 不要做的事

- **不要** 自己拼字符串而不验证长度 == 21。
- **不要** 把 strike 传成 `"170.00"` 字符串 —— 必须 `170.0` (float) 由
  build_osi 算出 `00170000`。
- **不要** 假设 root 就是 ticker —— 一些股票 ticker 含 `.` 或 `/`，OSI
  原样保留（`BRK.B` → root `BRK.B`，5 字符 + 1 空格）。

## 参考

- 期权 tool reference：[`../tools/tool-reference-options.md`](../tools/tool-reference-options.md)
- 输入验证错误处置：[`../troubleshooting/validation-osi-format.md`](../troubleshooting/validation-osi-format.md)
- OCC 官方说明：<https://en.wikipedia.org/wiki/Option_symbol>
