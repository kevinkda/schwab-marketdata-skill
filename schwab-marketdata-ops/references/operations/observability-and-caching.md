# Operations — Observability & caching

> server 与 agent 端的可观测性与缓存策略，避免反模式调用导致 quota
> 浪费。

## Server 端可观测信号

### 1. server.log（结构化）

默认路径：`${XDG_STATE_HOME:-~/.local/state}/schwab-marketdata-mcp/logs/server.log`

格式：`RotatingFileHandler` 10 MB × 5 rotated。每行一条结构化 log：

```text
2025-05-23 10:42:18,123 INFO  initialize received from clientInfo=...
2025-05-23 10:42:18,234 INFO  call_tool name=get_quote args={"symbol":"AAPL"}
2025-05-23 10:42:18,455 INFO  schwab_response status=200 elapsed_ms=210
2025-05-23 10:43:01,001 WARNING {"event":"rate_limit_warning","remaining":15}
2025-05-23 10:44:15,200 ERROR  schwab_response status=429 retry_after=30
```

### 2. health_check（实时快照）

```bash
uv run python -m schwab_marketdata_mcp.health
```

返回字段（详见 [`../tools/tool-reference-meta.md`](../tools/tool-reference-meta.md)）：

- `token_state` — 本地 token 状态
- `token_age_days` / `token_expires_in_days`
- `rate_limit_remaining_per_min`
- `recent_error_count_24h`
- `last_request_status`

### 3. stderr structured warning

`{"event":"rate_limit_warning","remaining":N}` —— bucket 剩余 < 20 时
触发。

## Agent 端缓存策略（强烈建议）

不是所有调用都需要每次去 server 拿。下表给出 agent 端**进程级**缓存
建议：

| Tool                          | 推荐 TTL  | 缓存键                                       |
| ----------------------------- | --------- | -------------------------------------------- |
| `get_server_info`             | 进程生命周期 | -（一次启动一次）                              |
| `get_market_hours`            | 30s        | (markets_list, date)                          |
| `get_market_hour_single`      | 30s        | (market_id, date)                            |
| `get_option_expiration_chain` | 60s        | symbol                                       |
| `health_check`                | **不缓存**  | -（每次都要看真实状态）                        |
| `get_quote` / `get_quotes`    | **不缓存**  | -（agent 拿到的是实时报价，缓存毫无意义）      |
| `get_price_history`           | 60s        | (symbol, period_type, period, frequency_type, frequency, start, end) |
| `get_movers`                  | 30s        | (index, sort_order, frequency)                |
| `search_instruments`          | 5 min      | (symbols, projection)                         |
| `get_instrument_by_cusip`     | 1 day      | cusip（基本面元数据稳定）                       |

### Python 极简实现

```python
import asyncio
import time

class TimedCache:
    def __init__(self, ttl_seconds: float):
        self.ttl = ttl_seconds
        self._store: dict[tuple, tuple[float, object]] = {}

    async def get_or_fetch(self, key: tuple, fetch):
        now = time.time()
        if key in self._store:
            t, v = self._store[key]
            if now - t < self.ttl:
                return v
        v = await fetch()
        self._store[key] = (now, v)
        return v


market_hours_cache = TimedCache(30)

async def cached_market_hours(client, markets_list):
    return await market_hours_cache.get_or_fetch(
        tuple(markets_list),
        lambda: client.call("get_market_hours", {"markets_list": list(markets_list)}),
    )
```

## 反模式与改写

| 反模式                                                   | 改写                                                              | 节省                |
| -------------------------------------------------------- | ----------------------------------------------------------------- | ------------------- |
| 循环 `get_quote(s)` for 50 symbols                       | 一次 `get_quotes(symbols=[...])`                                   | 50 slot → 1 slot    |
| 每分钟调 `get_market_hours` 看是否开市                    | 30s TTL 缓存                                                      | 60 slot → 2 slot    |
| 循环按天 `get_price_history(period_type="DAY", ...)`     | 一次 `get_price_history(period_type="MONTH", "SIX_MONTHS")` 切片 | N slot → 1 slot     |
| 反复 `get_server_info` 试探版本                          | skill 激活时调一次，进程级缓存                                    | M slot → 1 slot     |
| 实时报价缓存 60s                                         | **不缓存**                                                        | -（缓存 quote 是 bug）|

## 监控告警建议

### cron 巡检（详见 Quick Start Step 7）

```cron
0 */4 * * * /path/to/uv run python -m schwab_marketdata_mcp.health \
    | jq -e '.token_state == "valid" and .recent_error_count_24h < 50' \
    || /path/to/notify.sh "Schwab MCP unhealthy"
```

### 简单的本机 dashboard

```bash
# 把 health 结果打到 jq 看趋势
while true; do
    date
    uv run python -m schwab_marketdata_mcp.health \
        | jq -c '{token_state, expires: .token_expires_in_days, slots: .rate_limit_remaining_per_min, errs_24h: .recent_error_count_24h}'
    sleep 30
done
```

## 不要做的事

- **不要** 缓存 `health_check` —— 你想要看的就是实时状态。
- **不要** 缓存 `get_quote` / `get_quotes` —— 实时报价缓存毫无意义。
- **不要** 把缓存做到 disk —— 进程级 in-memory 足够，跨进程持久化反而
  容易过期。
- **不要** 把 server.log 的 INFO 级别打到第三方日志服务（含调用元数据，
  可推断你的策略）。

## 参考

- token-bucket 深度：[`rate-limit-token-bucket.md`](rate-limit-token-bucket.md)
- meta tool reference：[`../tools/tool-reference-meta.md`](../tools/tool-reference-meta.md)
- 健康巡检：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
