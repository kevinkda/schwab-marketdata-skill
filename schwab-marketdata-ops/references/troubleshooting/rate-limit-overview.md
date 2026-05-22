# Troubleshooting — Rate limit overview

> 4 种限流相关症状的快速分流。完整的 token-bucket 行为详解见
> [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)。

## 路由表

| 症状                                                          | 子文件                                                                |
| ------------------------------------------------------------- | --------------------------------------------------------------------- |
| Schwab 返回 `429 Too Many Requests`                            | [`rate-limit-429.md`](rate-limit-429.md)                              |
| token-bucket 0 slots 立即 raise（`retry_after_seconds == 0`）  | [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md) |
| stderr 出现 `rate_limit_warning`（remaining < 20）但调用成功    | [`rate-limit-warning-stderr.md`](rate-limit-warning-stderr.md)        |
| 429 但响应缺 `Retry-After` 头（罕见）                          | [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)        |

## 错误形态

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": <int>,        // 0 = 本机 token-bucket 0 slots；>0 = Schwab 服务端
  "current_window_used": <int>,        // 当前分钟窗口已用 slot
  "message": "Rate limit reached"
}
```

## Decision flow

1. **看 `retry_after_seconds`**：
   - `> 0` → Schwab 服务端 429；等待该秒数后重试一次。
   - `== 0` 或缺失 → 本机 token-bucket 0 slots；agent 端做指数退避。
2. **连续 2 次重试都失败** → 告诉用户，把并发 / 频率降下来。
3. **完全无 retry_after_seconds 字段** → 极罕见，参考
   [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)。

## 通用降压策略

| 场景                                       | 处置                                            |
| ------------------------------------------ | ----------------------------------------------- |
| 反复单点 `get_quote(SYM)` 调 N 次           | 改用一次 `get_quotes(symbols=[...])`             |
| 在循环里 `get_price_history` 拉日 K        | 改用大粒度（`MONTH`/`YEAR`）一次拿足              |
| 高频调 metadata（`get_market_hours` 等）    | agent 端做内存缓存，TTL 30s                     |
| 多 agent 并发                              | 把 `SCHWAB_RATE_LIMIT_PER_MIN` 调低              |
| 长期 batch 任务                            | playbook 拆分，每次 ≤ 30 个 tool call             |

## 不要做的事

- **不要** 在 `SchwabRateLimitError` 上立即重试同一调用 ≥ 3 次（会触发
  更严的服务端封锁）。
- **不要** 把 `SCHWAB_RATE_LIMIT_PER_MIN` 调到 > 120（Schwab 服务端会
  先发飙）。
- **不要** 在多 agent 并发场景假设各自独立 —— token-bucket 是 server 进
  程级共享。

## 参考

- token-bucket 深度：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 错误体系总览：[`../error-recovery.md`](../error-recovery.md)
- Authorization 错误：[`auth-overview.md`](auth-overview.md)
