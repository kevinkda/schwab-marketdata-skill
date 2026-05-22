# Troubleshooting — Price history cartesian product invalid

`get_price_history` 的 `(period_type, period, frequency_type, frequency)`
四元组只接受**受限组合**，非法组合 Schwab 服务端**静默 400**。MCP server
在 Pydantic 层提前拦截。

## Symptom

```text
{"error":"SchwabValidationError","field":"period_type|period|frequency_type|frequency","message":"..."}
```

`field` 通常是首个发现冲突的参数；`message` 含 Pydantic 的具体说明
（如 `"frequency_type DAILY is not allowed when period_type=DAY"`）。

## Root cause（3 种典型）

1. **`DAY` 配 `DAILY`** —— `period_type="DAY"` 只允许 `frequency_type="MINUTE"`
2. **`MONTH` 给了 `frequency` 值** —— `MONTH` 时 `frequency` 必须留空
3. **`YEAR_TO_DATE` 给了 `period` 值** —— `YEAR_TO_DATE` 时 `period`
   必须留空

## 完整合法组合表

| period_type    | legal `period`                                                          | legal `frequency_type`        | legal `frequency`        |
| -------------- | ----------------------------------------------------------------------- | ----------------------------- | ------------------------ |
| `DAY`          | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `FOUR_DAYS` / `FIVE_DAYS` / `TEN_DAYS` | `MINUTE`                       | `EVERY_MINUTE` / `EVERY_FIVE_MINUTES` / `EVERY_TEN_MINUTES` / `EVERY_FIFTEEN_MINUTES` / `EVERY_THIRTY_MINUTES` |
| `MONTH`        | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `SIX_MONTHS`                     | `DAILY` / `WEEKLY`             | (none — leave unset)     |
| `YEAR`         | `FIFTEEN_YEARS` / `TWENTY_YEARS`                                        | `DAILY` / `WEEKLY` / `MONTHLY` | (none)                    |
| `YEAR_TO_DATE` | (omit)                                                                  | `DAILY` / `WEEKLY`             | (none)                    |

## 修复模板

```python
# ❌ 拉日 K 一年，写错：
get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                  frequency_type="DAILY")  # 报错
# ✅ 拉 6 月日 K：
get_price_history(symbol="VOO", period_type="MONTH", period="SIX_MONTHS",
                  frequency_type="DAILY")
# ✅ 拉今日分钟 K：
get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                  frequency_type="MINUTE", frequency="EVERY_FIVE_MINUTES")
# ✅ 拉今年至今日 K：
get_price_history(symbol="VOO", period_type="YEAR_TO_DATE",
                  frequency_type="DAILY")
```

## 用 start/end datetime 替代 period

```python
from datetime import datetime, timezone

# 自定义起止时间（period 必须留空，二者互斥）
get_price_history(
    symbol="VOO",
    period_type="MONTH",
    frequency_type="DAILY",
    start_datetime=datetime(2024, 1, 1, tzinfo=timezone.utc),
    end_datetime=datetime(2024, 6, 30, tzinfo=timezone.utc),
)
```

注意：

- `start_datetime` / `end_datetime` 必须 **timezone-aware**
- 二者都不能在未来
- 同时给 `period` 与 `start_datetime/end_datetime` 会被 Pydantic 拒

## 验证

```python
result = await get_price_history(...)
assert result.get("error") is None
assert "candles" in result
assert len(result["candles"]) > 0
```

## 4 个非法组合排查清单

```python
def check_pricehistory_args(period_type, period, frequency_type, frequency):
    rules = {
        "DAY":          ("MINUTE", True),     # frequency 必填
        "MONTH":        (("DAILY","WEEKLY"), False),
        "YEAR":         (("DAILY","WEEKLY","MONTHLY"), False),
        "YEAR_TO_DATE": (("DAILY","WEEKLY"), False),
    }
    if period_type not in rules:
        return f"unknown period_type: {period_type}"
    legal_ft, freq_required = rules[period_type]
    if isinstance(legal_ft, str):
        legal_ft = (legal_ft,)
    if frequency_type not in legal_ft:
        return f"frequency_type {frequency_type} not allowed for period_type {period_type}"
    if freq_required and frequency is None:
        return f"frequency required for period_type {period_type}"
    if not freq_required and frequency is not None:
        return f"frequency must be unset for period_type {period_type}"
    return None
```

## 不要做的事

- **不要** 用 `period` 同时配 `start_datetime/end_datetime`（互斥）。
- **不要** 用 naive datetime（必须 TZ-aware）。
- **不要** 把 `period` 与 `frequency` 混淆 —— `period` 是回看窗口长度，
  `frequency` 是单根 K 线的细粒度。

## 参考

- Price history tool reference：[`../tools/tool-reference-price-history.md`](../tools/tool-reference-price-history.md)
- Validation overview：[`validation-overview.md`](validation-overview.md)
