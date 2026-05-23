# Tool reference — Streaming family (experimental)

`get_streaming_snapshot` —— bounded WebSocket snapshot via Schwab
Streamer。**实验性**，每次调用都建连 / 鉴权 / 订阅 / 关连接，单次约
300–500 ms 开销；不要频繁调用。长连接订阅模式留待 v0.3+ 的独立
streaming MCP server（计划 §10）。

## 1. `get_streaming_snapshot`

打开 Schwab Streamer WebSocket，按 `duration_ms` 收消息后断开，返回每只
symbol 的快照数组。

### 入参 schema

```text
get_streaming_snapshot(
  symbols: list[str],          # ≤ 20，UPPERCASE
  service: "LEVELONE_EQUITIES" | "CHART_EQUITY",
  duration_ms: int = 2000      # 硬上下界 [500, 10000]
)
```

### 入参字段

| 字段             | 类型               | 含义                                                                                       |
| ---------------- | ------------------ | ------------------------------------------------------------------------------------------ |
| `symbols`        | `list[str]`        | 订阅的 symbol（≤ 20）。受 `StockSymbol` 正则约束（UPPERCASE，可含 `.` `-` `/`）。           |
| `service`        | enum               | `LEVELONE_EQUITIES` 实时 bid/ask/last/volume；`CHART_EQUITY` 实时 1 分钟 K 线。              |
| `duration_ms`    | `int`，可选        | 收消息时长，默认 2000（2 秒）。下界 500 ms（建连/鉴权预算），上界 10000 ms（保守 MCP 超时）。 |

### 返回 schema

```text
{
  "service":            "LEVELONE_EQUITIES" | "CHART_EQUITY",
  "symbols_requested":  [...],          # 原样回显
  "symbols_received":   [...],          # 至少收到 1 帧的子集
  "duration_ms":        int,            # 默认应用后的实际值
  "messages_count":     int,            # 整段时长内收到的 data 帧数
  "snapshots": {
    "VOO": [
      {"ts": "<ISO 8601 UTC>", ...service-specific fields...},
      ...
    ],
    "QQQ": [...]
  },
  "metadata": {
    "first_message_at":        "<ISO>" | null,
    "last_message_at":         "<ISO>" | null,
    "connection_duration_ms":  int     # 实际 wall-clock 连接耗时
  }
}
```

### service 字段对照

#### `LEVELONE_EQUITIES`

每个 snapshot 帧：

| 字段     | 含义                                                  |
| -------- | ----------------------------------------------------- |
| `ts`     | 收到此帧的本地时间（ISO 8601 UTC）                    |
| `bid`    | 最新最高 bid 价                                       |
| `ask`    | 最新最低 ask 价                                       |
| `last`   | 最近一次成交价                                        |
| `volume` | 当日累计成交量                                        |

#### `CHART_EQUITY`

每个 snapshot 帧（一根 1 分钟 K 线）：

| 字段                | 含义                                                 |
| ------------------- | ---------------------------------------------------- |
| `ts`                | 收到此帧的本地时间（ISO 8601 UTC）                   |
| `open`              | 这一分钟的开盘价                                     |
| `high`              | 这一分钟的最高价                                     |
| `low`               | 这一分钟的最低价                                     |
| `close`             | 这一分钟的收盘价                                     |
| `volume`            | 这一分钟的成交量                                     |
| `chart_time_millis` | Schwab 端 K 线 epoch 毫秒时间戳                      |

### 调用示例

#### 拉 VOO / QQQ 2 秒实时报价

```text
get_streaming_snapshot(
  symbols=["VOO", "QQQ"],
  service="LEVELONE_EQUITIES",
  duration_ms=2000
)
```

#### 拉 SPY 5 秒实时 1 分钟 K 线

```text
get_streaming_snapshot(
  symbols=["SPY"],
  service="CHART_EQUITY",
  duration_ms=5000
)
```

### 何时用

- **REST 不够新鲜**：`get_quote` / `get_quotes` 返回的是 Schwab 缓存的
  延迟报价（约 5–15 s）；`get_streaming_snapshot` 走 WebSocket，亚秒级
  推送。
- **想要实时 1 分钟 K 线**：`get_price_history` 仅返回历史候选 K 线；
  实时新鲜的 1 分钟 K 线必须订阅 `CHART_EQUITY`。
- **限于"看一眼就够"的场景**：交易决策瞬间、shakeout 模型快照、
  开/收盘价捕获。**不**适合连续监控；那是 v0.3+ streaming server
  的活。

### 何时不用

- **频繁轮询**：每次调用都付出 300–500 ms 建连开销；轮询 > 1 Hz 极度
  浪费，改用 v0.3+ 的长连接 streaming server（计划 §10），现在没有
  替代方案就 fallback 到 `get_quotes`。
- **批量 > 20 symbol**：Pydantic 在入口拦截。
- **后台后台无人监管**：Schwab Streamer 本身在收盘时段也会维持连接，
  但 wallets 端 token-bucket 仍会消耗配额；尽量在 agent 触发的同步流
  中调。

### 注意事项

1. **每次调用消耗 1 slot**：与 REST tool 共享 `SCHWAB_RATE_LIMIT_PER_MIN`
   token-bucket。
2. **失败语义与 REST 一致**：失败一律转换为 `{"error": "Schwab*Error",
   ...}` dict 返回，不抛异常穿透 MCP 协议。
3. **关连接**：`finally` 块保证 `streamer.logout()` 一定调用，即便
   消息泵中途异常。
4. **盘后/低成交量**：消息流可能很稀；`messages_count` 为 0 是合法
   返回（`symbols_received` 为空，`metadata` 字段为 `null`）。
5. **OSI option symbol 不支持**：本 tool 接受的 symbol 必须匹配
   `StockSymbol` 正则（股票/ETF 根 + 可选 `.` `-` `/`），不接受 OSI
   21 字符期权 symbol，也不接受 `$` 前缀的指数 symbol。期权 / 指数
   实时报价请用 `get_quote`（REST，延迟）。

### 错误返回

| 错误                                | 触发场景                                             |
| ----------------------------------- | ---------------------------------------------------- |
| `SchwabValidationError(symbols)`    | 空列表 / > 20 个 / lowercase / 包含 OSI 或 `$` 前缀  |
| `SchwabValidationError(duration_ms)`| < 500 或 > 10000                                     |
| `SchwabValidationError(service)`    | 既不是 `LEVELONE_EQUITIES` 也不是 `CHART_EQUITY`     |
| `SchwabAuthError`                   | token 失效 / 权限错误（同 REST tool）                |
| `SchwabTransientError`              | streamer login 失败 / 网络抖动                       |

## 不要做的事

- **不要** 把这个 tool 当 keepalive 或长连接代理；每次调用最长 10 秒，
  超过 10 秒会被 Pydantic 拦下。
- **不要** 期望 fast batch 跨 50 symbol —— 容量上限 20，这是
  websocket 内存预算（每 symbol 帧数 × 字段数）的硬约束。
- **不要** 用 `LEVELONE_EQUITIES` 拉指数 / 期权报价 —— 该 service 仅
  支持股票 / ETF。
- **不要** 把这次的 `messages_count` 直接当作市场流量代理 —— 它取决
  于你订阅了几只 symbol、市场时段、symbol 流动性。

## 参考

- 实施代码：`src/schwab_marketdata_mcp/tools/streaming.py`
- 输入 schema：`schwab_marketdata_mcp.models.GetStreamingSnapshotInput`
- 边界拦截：[`../../troubleshooting/validation-overview.md`](../../troubleshooting/validation-overview.md)
- 长连接订阅 roadmap：MCP server `plan.md` §10
