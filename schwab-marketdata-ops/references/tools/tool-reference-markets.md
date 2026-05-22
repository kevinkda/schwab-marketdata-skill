# Tool reference — Markets family

`get_market_hours` / `get_market_hour_single` — 市场开闭市状态。

## 1. `get_market_hours(markets_list, date?)`

一次查 1-5 个市场的开闭市状态。

| Param         | Type / values                                                                  |
| ------------- | ------------------------------------------------------------------------------ |
| markets_list  | `list[MarketEnum]`：1-5 of `{"EQUITY", "OPTION", "BOND", "FUTURE", "FOREX"}`    |
| date          | TZ-aware datetime / date；不在未来超过 30 天；默认 = today                       |

### 调用示例

```text
get_market_hours(markets_list=["EQUITY", "OPTION"])
get_market_hours(markets_list=["EQUITY"], date=datetime(2024, 4, 19, tzinfo=timezone.utc))
```

### 返回 schema（节选）

```text
{
  "equity": {
    "EQ": {
      "date": "2024-04-19",
      "marketType": "EQUITY",
      "exchange": "NULL",
      "category": "EQ",
      "product": "EQ",
      "productName": "equity",
      "isOpen": true,
      "sessionHours": {
        "preMarket": [ { "start": "2024-04-19T07:00:00-04:00", "end": "2024-04-19T09:30:00-04:00" } ],
        "regularMarket": [ { "start": "2024-04-19T09:30:00-04:00", "end": "2024-04-19T16:00:00-04:00" } ],
        "postMarket": [ { "start": "2024-04-19T16:00:00-04:00", "end": "2024-04-19T20:00:00-04:00" } ]
      }
    }
  },
  "option": { ... }
}
```

## 2. `get_market_hour_single(market_id, date?)`

只查单个市场。

| Param      | Type / values                                                  |
| ---------- | -------------------------------------------------------------- |
| market_id  | `"EQUITY"` / `"OPTION"` / `"BOND"` / `"FUTURE"` / `"FOREX"`     |
| date       | 同上                                                            |

### 调用示例

```text
get_market_hour_single(market_id="EQUITY")
get_market_hour_single(market_id="BOND", date=datetime(2024, 7, 4, tzinfo=timezone.utc))
```

## 何时用哪一个？

| 场景                        | 用                            |
| --------------------------- | ----------------------------- |
| 一次只看 1 个市场            | `get_market_hour_single`     |
| 同时看 ≥ 2 个市场            | `get_market_hours`           |
| 只关心 `isOpen` 这一布尔字段 | 任一皆可，结构一致            |
| 计划性周末批量任务           | 缓存当天结果（30 min TTL 足够），别每次都调 |

## 时区注意事项

- `sessionHours` 的 `start` / `end` 都是带时区的 ISO 8601（通常是
  `-04:00` / `-05:00`），agent 不要假设是 UTC。
- `date` 输入接受 datetime / date，但 server 内部归一化到当地市场日期。
  传 `2024-04-19T22:00:00+00:00`（即 UTC 22:00）会被算作美东 18:00 仍属
  4/19 营业日。

## 假期处理

`isOpen == false` 不区分**周末** / **节假日** / **早闭市**。要区分得
读 `sessionHours` 是否完全为空（节假日）还是 `regularMarket` 提前结束
（早闭市，常见于 Black Friday、Christmas Eve）。

## 常见错误

| `error`                                            | 原因                                                       |
| -------------------------------------------------- | ---------------------------------------------------------- |
| `SchwabValidationError(field="markets_list")`     | 长度 0 或 > 5；含未列入的 enum 值                          |
| `SchwabValidationError(field="date")`              | naive datetime；超过当前日期 + 30 天                         |
| `equity.EQ.isOpen` 字段缺失                       | 极少出现，多半是上游缓存抖动；30 秒后重试一次               |

## 不要做的事

- **不要** 在 playbook 里循环里反复调 `get_market_hours`（高频 metadata）
  —— agent 应做内存缓存，TTL 30s 足够。
- **不要** 用本 tool 做 real-time market open/close 监听（数据是
  per-day quote，不是流式）。

## 参考

- 限流警告处置：[`../troubleshooting/rate-limit-warning-stderr.md`](../troubleshooting/rate-limit-warning-stderr.md)
- 缓存策略：[`../operations/observability-and-caching.md`](../operations/observability-and-caching.md)
