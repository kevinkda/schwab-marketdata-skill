# Troubleshooting — `rate_limit_warning` in stderr

stderr 出现结构化警告 `{"event":"rate_limit_warning","remaining":<20}`，
但业务 call **仍然成功**。这是预警，不是错误。

## Symptom

```text
2025-05-23 10:42:18,123 WARNING {"event":"rate_limit_warning","remaining":15}
2025-05-23 10:42:18,455 WARNING {"event":"rate_limit_warning","remaining":7}
```

业务 call 没有返回 `error` 字段；reply payload 正常。

## Root cause

本分钟内剩余 slot 已少于 20。这是 server 主动写出来的预警，提醒 agent
（或运维）即将耗尽。下一次同分钟窗口内的高频 call 就可能撞
[`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)。

## 检查命令

```bash
tail -n 100 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep rate_limit_warning
```

或当前剩余：

```bash
uv run python -m schwab_marketdata_mcp.health \
    | jq '.rate_limit_remaining_per_min'
```

## 修复策略

### 1. 把多次单点 → 批量

```python
# 反模式
for sym in symbols:
    await get_quote(sym)               # 1 slot per call

# 正确
await get_quotes(symbols=symbols[:50])  # 1 slot for 50 symbols
```

### 2. 减少 `get_price_history` 在循环内的频次

```python
# 反模式：循环按天拉 5 天日 K
for day in last_5_days:
    await get_price_history(period_type="DAY", period="ONE_DAY", ...)

# 正确：一次拉 6 个月日 K，agent 端切片
history = await get_price_history(
    period_type="MONTH", period="SIX_MONTHS",
    frequency_type="DAILY",
)
last_5 = [c for c in history["candles"] if recent(c["datetime"])]
```

### 3. metadata 高频调用做内存缓存

```python
# 反模式：每次调用都 get_market_hours
async def is_market_open():
    h = await get_market_hours(markets_list=["EQUITY"])
    return h["equity"]["EQ"]["isOpen"]

# 正确：进程级缓存 30s
_cache = {}
async def is_market_open():
    now = time.time()
    if "v" in _cache and now - _cache["t"] < 30:
        return _cache["v"]
    h = await get_market_hours(markets_list=["EQUITY"])
    v = h["equity"]["EQ"]["isOpen"]
    _cache.update(t=now, v=v)
    return v
```

## 验证

观察后续若干分钟内 warning 不再出现，且 `recent_error_count_24h`
持平。

```bash
sleep 300   # 等 5 分钟
tail -n 200 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep -c rate_limit_warning   # 应当较低
```

## 阈值是 20 的设计动机

20 ≈ 16% × 120，给 agent **大约 10s** 反应时间（按 ~120 req/min 推算）
做出退避决策。设得更高会预警太频繁；更低则没有缓冲窗口。

## 不要做的事

- **不要** 把 `rate_limit_warning` 当成业务错误处理（call 仍成功）。
- **不要** 把它写到用户可见的 chat（应该静默地驱动 agent 自己降速）。

## 参考

- 0 slots 真错误：[`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)
- token-bucket 实现：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 缓存策略：[`../operations/observability-and-caching.md`](../operations/observability-and-caching.md)
