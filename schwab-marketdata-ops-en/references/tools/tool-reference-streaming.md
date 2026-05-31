# Tool reference — Streaming family (experimental)

`get_streaming_snapshot` — a bounded WebSocket snapshot via the Schwab
Streamer. **Experimental.** Every call opens a connection, authenticates,
subscribes, and tears the connection down again, costing roughly 300–500 ms
per call; do not poll it frequently. The persistent long-lived subscription
mode is deferred to the standalone streaming MCP server planned for v0.3+
(plan §10).

## 1. `get_streaming_snapshot`

Opens the Schwab Streamer WebSocket, collects messages for `duration_ms`, then
disconnects, returning a snapshot array per symbol.

### Input schema

```text
get_streaming_snapshot(
  symbols: list[str],          # ≤ 20, UPPERCASE
  service: "LEVELONE_EQUITIES" | "CHART_EQUITY",
  duration_ms: int = 2000      # hard bounds [500, 10000]
)
```

### Input fields

| Field         | Type            | Meaning                                                                                          |
| ------------- | --------------- | ------------------------------------------------------------------------------------------------ |
| `symbols`     | `list[str]`     | Symbols to subscribe (≤ 20). Constrained by the `StockSymbol` regex (UPPERCASE, may contain `.` `-` `/`). |
| `service`     | enum            | `LEVELONE_EQUITIES` for live bid/ask/last/volume; `CHART_EQUITY` for live 1-minute candles.       |
| `duration_ms` | `int`, optional | Collection window, default 2000 (2 s). Lower bound 500 ms (connect/auth budget), upper bound 10000 ms (conservative MCP timeout). |

### Return schema

```text
{
  "service":            "LEVELONE_EQUITIES" | "CHART_EQUITY",
  "symbols_requested":  [...],          # echoed verbatim
  "symbols_received":   [...],          # subset that received ≥ 1 frame
  "duration_ms":        int,            # actual value after defaulting
  "messages_count":     int,            # data frames received across the window
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
    "connection_duration_ms":  int     # actual wall-clock connection time
  }
}
```

### service field reference

#### `LEVELONE_EQUITIES`

Each snapshot frame:

| Field    | Meaning                                              |
| -------- | ---------------------------------------------------- |
| `ts`     | Local time the frame was received (ISO 8601 UTC)     |
| `bid`    | Latest highest bid price                             |
| `ask`    | Latest lowest ask price                              |
| `last`   | Most recent trade price                              |
| `volume` | Cumulative volume for the day                        |

#### `CHART_EQUITY`

Each snapshot frame (one 1-minute candle):

| Field               | Meaning                                              |
| ------------------- | ---------------------------------------------------- |
| `ts`                | Local time the frame was received (ISO 8601 UTC)     |
| `open`              | Open price for this minute                           |
| `high`              | High price for this minute                           |
| `low`               | Low price for this minute                            |
| `close`             | Close price for this minute                          |
| `volume`            | Volume for this minute                               |
| `chart_time_millis` | Schwab-side candle epoch-millisecond timestamp       |

### Examples

#### Pull 2 seconds of live VOO / QQQ quotes

```text
get_streaming_snapshot(
  symbols=["VOO", "QQQ"],
  service="LEVELONE_EQUITIES",
  duration_ms=2000
)
```

#### Pull 5 seconds of live 1-minute SPY candles

```text
get_streaming_snapshot(
  symbols=["SPY"],
  service="CHART_EQUITY",
  duration_ms=5000
)
```

### When to use

- **REST is not fresh enough**: `get_quote` / `get_quotes` return Schwab's
  cached delayed quotes (~5–15 s); `get_streaming_snapshot` rides the
  WebSocket for sub-second pushes.
- **You want live 1-minute candles**: `get_price_history` only returns
  historical candidate candles; a fresh, live 1-minute candle must be
  obtained by subscribing to `CHART_EQUITY`.
- **A "just take a peek" scenario**: the instant of a trade decision, a
  shakeout-model snapshot, open/close price capture. **Not** for continuous
  monitoring — that is the job of the v0.3+ streaming server.

### When not to use

- **Frequent polling**: every call pays the 300–500 ms connect overhead;
  polling > 1 Hz is extremely wasteful. Use the v0.3+ long-lived streaming
  server (plan §10) instead, or fall back to `get_quotes` while no
  alternative exists.
- **Batches > 20 symbols**: Pydantic rejects this at the boundary.
- **Unattended background loops**: the Schwab Streamer keeps connections
  alive even after hours, but the wallet-side token bucket still consumes
  quota; prefer calling it inside an agent-triggered synchronous flow.

### Cautions

1. **Each call consumes 1 slot**: it shares the
   `SCHWAB_RATE_LIMIT_PER_MIN` token bucket with the REST tools.
2. **Failure semantics match REST**: any failure is converted to an
   `{"error": "Schwab*Error", ...}` dict return; no exception leaks
   through the MCP protocol.
3. **Connection teardown**: a `finally` block guarantees
   `streamer.logout()` is always called, even if the message pump raises
   midway.
4. **After hours / low volume**: the message stream may be sparse; a
   `messages_count` of 0 is a legal return (`symbols_received` empty,
   `metadata` fields `null`).
5. **OSI option symbols unsupported**: the symbols this tool accepts must
   match the `StockSymbol` regex (stock/ETF root + optional `.` `-` `/`); it
   does not accept the 21-character OSI option symbol, nor `$`-prefixed
   index symbols. For live option / index quotes use `get_quote` (REST,
   delayed).

### Error returns

| Error                                | Trigger                                              |
| ------------------------------------ | ---------------------------------------------------- |
| `SchwabValidationError(symbols)`     | empty list / > 20 / lowercase / contains OSI or `$` prefix |
| `SchwabValidationError(duration_ms)` | < 500 or > 10000                                     |
| `SchwabValidationError(service)`     | neither `LEVELONE_EQUITIES` nor `CHART_EQUITY`       |
| `SchwabAuthError`                    | token invalid / permission error (same as REST tools) |
| `SchwabTransientError`               | streamer login failure / network jitter              |

## What not to do

- **Do not** treat this tool as a keepalive or long-lived connection proxy;
  each call lasts at most 10 seconds, and exceeding 10 seconds is rejected
  by Pydantic.
- **Do not** expect a fast batch across 50 symbols — the capacity ceiling is
  20, a hard constraint of the websocket memory budget (frames-per-symbol ×
  fields).
- **Do not** use `LEVELONE_EQUITIES` to pull index / option quotes — that
  service supports stocks / ETFs only.
- **Do not** treat this call's `messages_count` as a market-traffic proxy —
  it depends on how many symbols you subscribed, the market session, and
  symbol liquidity.

## References

- Implementation: `src/schwab_marketdata_mcp/tools/streaming.py`
- Input schema: `schwab_marketdata_mcp.models.GetStreamingSnapshotInput`
- Boundary interception: [`../../troubleshooting/validation-overview.md`](../../troubleshooting/validation-overview.md)
- Long-lived subscription roadmap: MCP server `plan.md` §10
