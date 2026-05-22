# Troubleshooting — Validation overview

`SchwabValidationError` 是 MCP server 在 **本地 Pydantic 层** 拒绝的输入
错误，**不消耗** Schwab API 配额。错误返回时一定带 `field` 字段指向
出错参数。

## 4 种症状路由

| 症状                              | 子文件                                                                              |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| `field="symbol"` / `"symbols"`    | [`validation-symbol.md`](validation-symbol.md)                                       |
| price history 笛卡尔积非法         | [`validation-pricehistory-cartesian.md`](validation-pricehistory-cartesian.md)        |
| `get_quotes` 超 50 symbol          | [`validation-batch-50.md`](validation-batch-50.md)                                  |
| OSI 期权 symbol 格式错             | [`validation-osi-format.md`](validation-osi-format.md)                              |

## 错误形态

```text
{
  "error": "SchwabValidationError",
  "field": "symbol|symbols|period_type|period|frequency_type|frequency|cusip|projection|...",
  "message": "..."
}
```

`field` 字段精确指向 Pydantic 模型上失败的属性名。`message` 通常引用
Pydantic 的 validator 报文（例如 `"string does not match regex
'^[A-Z$./ ]{1,21}$'"`）。

## Decision flow

1. **修正输入后重试一次**（`aapl` → `AAPL`、把 60 个 symbol 拆成 50 +
   10）；修正后仍失败才打扰用户。
2. **不要** 把 validation error 当成 server bug —— 99% 是输入参数问题。
3. **不要** 在 agent 侧用正则做二次验证 —— server 已经做了；agent 只需
   修正参数。

## 通用修复模板

```python
import re

def normalize_symbol(s: str) -> str:
    s = s.strip().upper()
    if not re.fullmatch(r'[A-Z$./ ]{1,21}', s):
        raise ValueError(f"unfit symbol: {s!r}")
    return s

def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]
```

## 不要做的事

- **不要** 跳过 `SchwabValidationError` 直接重试同一参数（必然再次失败）。
- **不要** 把验证错误当成 server bug 上报（绝大多数是输入参数问题；先
  对照本路由表）。
- **不要** 在 agent 侧用正则做二次验证，server 已经做了；agent 只需修
  正参数后重试一次。

## 参考

- 错误体系总览：[`../error-recovery.md`](../error-recovery.md)
- 12 tool schema：[`../tools/index.md`](../tools/index.md)
