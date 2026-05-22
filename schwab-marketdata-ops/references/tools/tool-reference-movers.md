# Tool reference — Movers family

`get_movers` — 当日 top movers。

## Signature

```text
get_movers(
    index: MoversIndex,
    sort_order: MoversSortOrder | None = None,
    frequency: MoversFrequency | None = None,
)
```

| Param      | Values                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| index      | `DJI` / `COMPX` / `SPX` / `NYSE` / `NASDAQ` / `OTCBB` / `INDEX_ALL` / `EQUITY_ALL` / `OPTION_ALL` / `OPTION_PUT` / `OPTION_CALL` |
| sort_order | `VOLUME` / `TRADES` / `PERCENT_CHANGE_UP` / `PERCENT_CHANGE_DOWN`                                            |
| frequency  | `ZERO` / `ONE` / `FIVE` / `TEN` / `THIRTY` / `SIXTY`                                                         |

注意 enum 名都是 **MCP server 用的 schwab-py 名**，不是 wire 值（例如
`"DJI"` 而非 `"$DJI"`）。

## 调用示例

```text
# 道琼斯成分股按成交量排序
get_movers(index="DJI", sort_order="VOLUME")

# 纳指 100 涨幅最大
get_movers(index="COMPX", sort_order="PERCENT_CHANGE_UP")

# 跌幅最大（前 10 分钟内）
get_movers(index="SPX", sort_order="PERCENT_CHANGE_DOWN", frequency="TEN")

# 全市场期权 call top movers
get_movers(index="OPTION_CALL", sort_order="VOLUME")
```

## 返回 schema（节选）

```text
{
  "screeners": [
    {
      "symbol": "AAPL",
      "description": "APPLE INC",
      "lastPrice": 175.10,
      "marketShare": 6.34,
      "totalVolume": 12345678,
      "trades": 56789,
      "netChange": 1.23,
      "netPercentChange": 0.71,
      "volume": 12345678
    },
    ...
  ]
}
```

## sort_order 语义

| 值                       | 排序键                  | 升降序  |
| ------------------------ | ----------------------- | ------- |
| `VOLUME`                 | `totalVolume`           | 降序    |
| `TRADES`                 | `trades`                | 降序    |
| `PERCENT_CHANGE_UP`      | `netPercentChange`     | 降序    |
| `PERCENT_CHANGE_DOWN`    | `netPercentChange`     | 升序    |

## frequency 语义

| 值        | 含义                                       |
| --------- | ------------------------------------------ |
| `ZERO`    | 无最小变化阈值（默认；返回全部 mover）     |
| `ONE`     | ≥ 1% 变化才入选                            |
| `FIVE`    | ≥ 5%                                       |
| `TEN`     | ≥ 10%                                      |
| `THIRTY`  | ≥ 30%                                      |
| `SIXTY`   | ≥ 60%（极端筛选；通常只返回 small-cap 或停牌脉冲）|

## index 选择指南

| 用户想看                          | 用                  |
| --------------------------------- | ------------------- |
| 道琼斯 30 成分股                   | `DJI`               |
| 纳指 100 / 综合纳指                | `COMPX`             |
| 标普 500                          | `SPX`               |
| 纽交所全部                         | `NYSE`              |
| 纳斯达克交易所全部                | `NASDAQ`            |
| OTC（场外）                        | `OTCBB`             |
| 全部三大主流指数合并               | `INDEX_ALL`         |
| 全部 equity（含 OTC）              | `EQUITY_ALL`        |
| 期权（put + call）                 | `OPTION_ALL`        |
| 仅 put                            | `OPTION_PUT`        |
| 仅 call                           | `OPTION_CALL`       |

## 常见错误

| `error`                                        | 原因                                                   |
| ---------------------------------------------- | ------------------------------------------------------ |
| `SchwabValidationError(field="index")`         | 拼错（如传了 `"$DJI"` 而非 `"DJI"`）                    |
| `SchwabValidationError(field="frequency")`    | 不在合法枚举里                                          |
| `screeners == []`                             | 当日交易未开始 / 早盘前 / 节假日；调用时段问题，先 `get_market_hours` |

## 不要做的事

- **不要** 把 `frequency` 当成时间窗口来理解 —— 它是**百分比阈值**，
  不是 lookback 时长。
- **不要** 在 pre-market 调（`isOpen == false` 且非美东 09:30+）—— 一定
  返回空 list。

## 参考

- 多市场状态：[`tool-reference-markets.md`](tool-reference-markets.md)
- 验证错误处置：[`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
