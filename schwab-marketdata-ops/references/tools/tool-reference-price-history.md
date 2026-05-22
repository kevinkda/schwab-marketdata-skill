# Tool reference — Price history family

`get_price_history` — 历史 K 线 / OHLC 数据。

## Signature

```text
get_price_history(
    symbol: str,
    period_type: PeriodType,
    period: Period | None = None,
    frequency_type: FrequencyType,
    frequency: Frequency | None = None,
    start_datetime: datetime | None = None,
    end_datetime: datetime | None = None,
    need_extended_hours_data: bool | None = None,
    need_previous_close: bool | None = None,
)
```

## Cartesian-product 合法组合（关键约束）

Schwab 对 `(period_type, period, frequency_type, frequency)` 四元组只
接受**受限组合**，非法组合服务端**静默返回 400**。MCP server 在
Pydantic 层提前拦截，避免对计费配额的浪费。

| period_type    | legal `period`                                                                            | legal `frequency_type`        | legal `frequency`                          |
| -------------- | ----------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------ |
| `DAY`          | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `FOUR_DAYS` / `FIVE_DAYS` / `TEN_DAYS`             | `MINUTE`                       | `EVERY_MINUTE` / `EVERY_FIVE_MINUTES` / `EVERY_TEN_MINUTES` / `EVERY_FIFTEEN_MINUTES` / `EVERY_THIRTY_MINUTES` |
| `MONTH`        | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `SIX_MONTHS`                                       | `DAILY` / `WEEKLY`             | (none — leave unset)                       |
| `YEAR`         | `FIFTEEN_YEARS` / `TWENTY_YEARS`                                                          | `DAILY` / `WEEKLY` / `MONTHLY` | (none)                                     |
| `YEAR_TO_DATE` | (omit)                                                                                    | `DAILY` / `WEEKLY`             | (none)                                     |

## datetime 字段规则

- `start_datetime` / `end_datetime` 必须 **timezone-aware**（`+00:00`、
  `-04:00` 等），传 naive datetime 会被 Pydantic 拒。
- 不允许在未来。
- 给了 `start_datetime` / `end_datetime` 时，`period` 应留空 —— 二者
  互斥。

## 调用示例

### 拉今天分钟 K（5 分钟粒度）

```text
get_price_history(
    symbol="VOO",
    period_type="DAY",
    period="ONE_DAY",
    frequency_type="MINUTE",
    frequency="EVERY_FIVE_MINUTES",
)
```

### 拉过去 6 个月日 K

```text
get_price_history(
    symbol="VOO",
    period_type="MONTH",
    period="SIX_MONTHS",
    frequency_type="DAILY",
)
```

### 拉过去 15 年周 K

```text
get_price_history(
    symbol="VOO",
    period_type="YEAR",
    period="FIFTEEN_YEARS",
    frequency_type="WEEKLY",
)
```

### 自定义起止时间

```python
from datetime import datetime, timezone

get_price_history(
    symbol="VOO",
    period_type="MONTH",
    frequency_type="DAILY",
    start_datetime=datetime(2024, 1, 1, tzinfo=timezone.utc),
    end_datetime=datetime(2024, 6, 30, tzinfo=timezone.utc),
)
```

## 返回 schema（节选）

```text
{
  "symbol": "VOO",
  "candles": [
    { "open": ..., "high": ..., "low": ..., "close": ..., "volume": ..., "datetime": <epoch_ms> },
    ...
  ],
  "empty": false,
  "previousClose": ...,            # 仅 need_previous_close=True 时有
  "previousCloseDate": ...,
  "previousCloseDateISO8601": ...
}
```

`datetime` 是 epoch milliseconds（注意是毫秒，不是秒）。在 agent 侧
转换：

```python
from datetime import datetime, timezone

ts = datetime.fromtimestamp(candle["datetime"] / 1000, tz=timezone.utc)
```

## 常见错误

| `error`                                                              | 原因                                                                          |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `SchwabValidationError(field="period_type"/"period"/"frequency_*")` | 笛卡尔积非法（最常见：`DAY` 配 `DAILY`）                                       |
| `SchwabValidationError(field="start_datetime"/"end_datetime")`     | 传了 naive datetime，或时间在未来                                              |
| `candles == []` + `empty: true` 但无 error                          | 合法调用但无数据（休市日 / 退市 symbol / 时间窗早于上市日）                     |

## 配额优化建议

- 拉长历史尽量用大粒度（`MONTH` / `YEAR` + `DAILY` / `WEEKLY`），不要按
  日循环 200 次拉日 K。
- `need_extended_hours_data=False` 默认即可；要 pre-/after-market 才打开。
- 想要做时序补全，先一次性拉 `FIFTEEN_YEARS`，再在 agent 侧切片，比反
  复调 API 省 quota。

## 不要做的事

- **不要** 把 OSI option symbol 传进来 —— price history 只支持 stock /
  ETF / index。
- **不要** 同时给 `period` 与 `start_datetime/end_datetime`。

## 参考

- 输入验证错误：[`../troubleshooting/validation-pricehistory-cartesian.md`](../troubleshooting/validation-pricehistory-cartesian.md)
- 限流与配额：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
