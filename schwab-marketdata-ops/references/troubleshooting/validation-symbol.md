# Troubleshooting — `SchwabValidationError(field="symbol")`

symbol / symbols 字段不通过 Pydantic 正则。常见 4 种触发形态。

## Symptom

```text
{"error":"SchwabValidationError","field":"symbol","message":"...does not match…"}
{"error":"SchwabValidationError","field":"symbols","message":"..."}
```

## Root cause（4 种典型）

1. **小写 ticker** —— `"aapl"`；必须 UPPERCASE
2. **含非法字符** —— `"BRK.B "`（尾随空格）/ `"AAPL\t"`（含 tab）
3. **把指数当股票** —— `"SPX"` 而非 `"$SPX"`
4. **把 OSI option 当作 stock** —— OSI 只能进 `get_quote/get_quotes`，
   不能进 `get_option_chain`

## 检查命令

对照 [`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md)
§1 的合法格式表。

## 修复模板

```python
# ❌ get_quote("aapl") → 报错
# ✅
get_quote("AAPL")
get_quote("$SPX")                          # 指数
get_quote("BRK.B")                         # ETF / 含点
get_quote("BF/B")                          # 含斜杠
get_quote("AAPL  240119C00170000")         # OSI 21 字符（root 6 字符空格右补齐）
```

## 4 种合法 symbol 形态

| 类型           | 示例                              | 正则约束                                |
| -------------- | --------------------------------- | --------------------------------------- |
| 普通股 / ETF   | `AAPL` / `MSFT` / `BRK.B` / `BF/B` | `[A-Z][A-Z./]{0,9}`                     |
| 指数           | `$SPX` / `$DJI` / `$COMPX`         | `\$[A-Z]{1,6}`                          |
| OSI 期权        | `AAPL  240119C00170000`            | `[A-Z][A-Z]{0,5} {0,5}\d{6}[CP]\d{8}` 共 21 字符 |
| Forex（罕见）  | `EUR/USD` / `USD/JPY`             | `[A-Z]{3}/[A-Z]{3}`                     |

## 自检 helper

```python
import re

SYMBOL_RE = re.compile(r"^[A-Z$./ ]{1,21}$")

def assert_symbol_ok(s: str) -> None:
    if not SYMBOL_RE.fullmatch(s):
        raise ValueError(f"invalid symbol shape: {s!r}")
```

注意 `s` 必须先 `s.strip().upper()` 再校验。

## 验证

修复后重试同一调用，错误消失：

```python
quote = await get_quote("AAPL")
assert "error" not in quote or quote["error"] is None
```

## 不要做的事

- **不要** 在 agent 侧二次实现 symbol 正则 —— server 已经做了；agent 只
  需 normalize（strip + upper）。
- **不要** 把 OSI 当成 stock 传到 `get_option_chain` —— 用
  `get_option_expiration_chain` 拿到日期列表，再 `get_option_chain`。
- **不要** 把多个 symbol 用逗号拼成一个字符串传 `get_quote` —— 用
  `get_quotes(symbols=[...])` 列表参数。

## 参考

- Quotes tool reference：[`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md)
- OSI 详解：[`../concepts/osi-option-symbol.md`](../concepts/osi-option-symbol.md)
- Validation overview：[`validation-overview.md`](validation-overview.md)
