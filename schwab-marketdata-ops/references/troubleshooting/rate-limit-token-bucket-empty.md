# Troubleshooting — token-bucket 0 slots（瞬时打满）

业务 tool **立即** raise `SchwabRateLimitError`，`retry_after_seconds == 0`
或缺失。这是本机限流先于 Schwab 触发的预期行为，由 agent 决定退避节奏。

## Symptom

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": 0,          // 注意是 0，不是大数字
  "current_window_used": 120,
  "message": "Local token-bucket exhausted"
}
```

且：

- stderr 已经 / 即将出现 `{"event":"rate_limit_warning","remaining":<20}`
- 调用没有真的发到 Schwab（不消耗服务端配额）
- 没有 `Retry-After` HTTP 头痕迹（因为 server 没去调 Schwab）

## Root cause

本机 token-bucket 容量打满（同一分钟窗口内已发出 ≥ 120 个请求）。
server **不阻塞**而是立即 raise，把节流决策交给 agent。这是
`Semaphore` vs `token-bucket` 选型的一个有意设计 —— 避免 retry sleep
阻塞别的 tool。

详见 [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)。

## 检查命令

```bash
# 在调用瞬间看 stderr 日志
tail -f ~/.local/state/schwab-marketdata-mcp/logs/server.log
# 期望：之前应已出现
#   {"event":"rate_limit_warning","remaining":15}
#   {"event":"rate_limit_warning","remaining":3}
```

或调 health：

```bash
uv run python -m schwab_marketdata_mcp.health \
  | jq '.rate_limit_remaining_per_min'
# 接近 0 = bucket 耗尽
```

## 修复策略（agent 端）

### 指数退避重试

```python
import asyncio

async def call_with_backoff(call, max_attempts=3):
    for attempt in range(max_attempts):
        result = await call()
        err = result.get("error")
        if err != "SchwabRateLimitError":
            return result
        wait = 2 ** attempt   # 1s, 2s, 4s
        await asyncio.sleep(wait)
    raise RuntimeError("rate limit exhausted after backoff")
```

### TypeScript 等价

```typescript
async function callWithBackoff<T>(
    call: () => Promise<{ error?: string } & T>,
    maxAttempts = 3,
): Promise<T> {
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
        const result = await call();
        if (result.error !== "SchwabRateLimitError") return result;
        await new Promise((r) => setTimeout(r, 2 ** attempt * 1000));
    }
    throw new Error("rate limit exhausted after backoff");
}
```

### 下一次 batch 前降并发

```python
# 错误：60 个 symbol 同时并发
results = await asyncio.gather(*[get_quote(s) for s in symbols])

# 正确：用 batch tool（一个 slot 拿 ≤ 50 个 symbol）
result = await get_quotes(symbols=symbols[:50])
```

## 为什么不让 server 自己 sleep？

如果 server 用 `asyncio.Semaphore` 自动 await 直到有 slot，会出现：

1. **阻塞**：调用方以为 call 还在跑，实际是在排队等 slot。
2. **协议超时**：MCP client 默认 30s timeout，长 sleep 会让 client
   断连。
3. **影响并发**：retry sleep 期间 slot 被持有，别的并发 tool 也得排队。

token-bucket + 立即 raise 让 agent 自己掌控节奏，是更好的契约。

## 验证

```bash
# 连续 3 次重试都不再立即 raise
for i in 1 2 3; do
    sleep 5
    # 调一次轻量 tool
    ...
done
```

## 不要做的事

- **不要** 把 retry 时间设小于 1s（无意义，bucket 至少要等 60s 才有 slot）。
- **不要** 通过启动多个 server 进程绕过限制（token-bucket 是 server 进程
  级，多进程加起来仍受 Schwab 限制）。
- **不要** 修改 server 代码移除限流（你会被 Schwab 服务端封锁更狠）。

## 参考

- 限流总览：[`rate-limit-overview.md`](rate-limit-overview.md)
- token-bucket 深度：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 服务端 429：[`rate-limit-429.md`](rate-limit-429.md)
