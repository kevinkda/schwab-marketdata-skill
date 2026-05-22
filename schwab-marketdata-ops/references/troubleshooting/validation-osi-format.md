# Troubleshooting — OSI option symbol format error

OSI option symbol 必须**精确 21 字符**，否则 Pydantic 拒。

## Symptom

```text
{"error":"SchwabValidationError","field":"symbol","message":"invalid OSI format"}
```

## 4 种典型违规

| 错误形式                          | 长度 | 修复                                          |
| --------------------------------- | ---- | --------------------------------------------- |
| `"AAPL240119C00170000"`           | 19   | root 不足 6 字符未空格右补齐 → `"AAPL  240119C00170000"` |
| `"AAPL  2024-01-19C00170000"`     | 25   | 日期不是 `YYMMDD` → `"AAPL  240119C00170000"` |
| `"AAPL  240119X00170000"`         | 21   | C/P 字段不是 `C`/`P` → `C` 或 `P`             |
| `"AAPL  240119C00170"`            | 18   | strike 不是 8 位整数 → `"AAPL  240119C00170000"` |

## 检查命令

```python
symbol = "AAPL  240119C00170000"
assert len(symbol) == 21, f"OSI 必须 21 字符，当前 {len(symbol)}"
assert symbol[6:12].isdigit(), "YYMMDD 必须 6 位数字"
assert symbol[12] in ("C", "P"), "第 13 位必须 C 或 P"
assert symbol[13:].isdigit() and len(symbol[13:]) == 8, "strike 必须 8 位整数"
```

## 修复模板

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

## 验证

```python
osi = build_osi("AAPL", "240119", "C", 170.0)
assert len(osi) == 21
quote = await get_quote(symbol=osi)
assert "error" not in quote or quote["error"] is None
# 含 option-specific 字段
assert "delta" in quote.get("quote", {}) or "delta" in quote.get("option", {})
```

## 几个 root 长度的样例

| Root  | Root 段（6 字符）        | 完整 OSI 例                   |
| ----- | ------------------------ | ----------------------------- |
| AAPL  | `"AAPL  "`（4 + 2 空格）  | `AAPL  240119C00170000`       |
| BRK/B | `"BRK/B "`（5 + 1 空格）  | `BRK/B 240419P00350000`       |
| SPY   | `"SPY   "`（3 + 3 空格）  | `SPY   251219C00500000`       |
| AMZN  | `"AMZN  "`（4 + 2 空格）  | `AMZN  240920C00150500`       |
| BF/B  | `"BF/B  "`（4 + 2 空格）  | `BF/B  240517P00040000`       |

## 不要做的事

- **不要** 在 agent 侧写正则二次验证 —— server 已经做了；agent 用
  `build_osi` helper 构造即可。
- **不要** 把 OSI 传进 `get_option_chain` —— 后者只接受 stock/ETF。
- **不要** 假设 root 段一定是 ticker —— 含 `.` 或 `/` 的 ticker 原样
  保留。

## 参考

- OSI 详解：[`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- Options tool reference：[`../tools/tool-reference-options.md`](../tools/tool-reference-options.md)
- Validation overview：[`validation-overview.md`](validation-overview.md)
