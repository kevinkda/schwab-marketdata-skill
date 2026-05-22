# Rate limits & paging

## Schwab's official limits

Schwab does not publish exact per-account quotas.  Community measurement
suggests **~120 req/min/user** for Market Data Production.  The
`schwab-marketdata-mcp` server defaults to that value via
`SCHWAB_RATE_LIMIT_PER_MIN=120`.

## How the server enforces it

A **token-bucket** with sliding-window expiry sits in front of every
schwab-py call:

- Bucket capacity = `SCHWAB_RATE_LIMIT_PER_MIN` (default 120).
- Each request consumes 1 slot; the slot auto-recovers `60 s` later.
- When fewer than `20` slots remain, a structured `WARNING` line is
  written to stderr (`{"event":"rate_limit_warning","remaining":N}`).
- When `0` slots remain, the next call **immediately** raises
  `SchwabRateLimitError` instead of blocking; the agent decides how to
  pace itself.

> **Why not `asyncio.Semaphore`?**  A Semaphore would keep its slot
> across an automatic retry sleep, blocking unrelated tools.  The
> token-bucket releases the slot during retry sleep so other concurrent
> tools can keep going.

## Paging

The current 10 endpoints **do not** support cursor-based paging.  When
you need many quotes:

1. Split the symbol list into ≤50-symbol batches yourself.  The server
   will **reject** a 51-symbol `get_quotes` with
   `SchwabValidationError(field="symbols")`.
2. Stagger calls by ~0.5 s if you are near the per-minute budget; or
   set `SCHWAB_RATE_LIMIT_PER_MIN` lower to make the local limiter
   pre-empt before Schwab does.

For historical price history, use `period_type="DAY"/"MONTH"/"YEAR"` to
adjust the granularity rather than asking for many ranges.

## Retry-After honoring

When Schwab returns `429 Too Many Requests`, the server:

1. Reads the `Retry-After` header (seconds).
2. Sleeps that long **without** holding a bucket slot.
3. Retries up to `SCHWAB_MAX_RETRIES` times (default 2).

After the retry budget is exhausted, the call is reported as
`SchwabRateLimitError(retry_after_seconds=…, current_window_used=…)`
to the agent.

## Disabling retries (for tests)

```bash
SCHWAB_MAX_RETRIES=0 uv run pytest …
```

The integration tests use this so a flaky scenario fails fast instead
of consuming the test runner's wall time.

## Troubleshooting

3 个常见症状的快速处置（完整版见 `troubleshooting-rate-limit.md`）：

### 1. `rate_limit_warning`（剩余 < 20）

stderr 出现 `{"event":"rate_limit_warning","remaining":<20}` 但业务 call 仍成功。

- **建议**：把多次单点 `get_quote` 合并为一次 `get_quotes`（最多 50 symbol = 1 slot）。
- **建议**：减少 `get_price_history` 在循环内的频次；用大粒度 `period_type` 一次拿足。
- **建议**：playbook 编排时把高频 metadata 调用（`get_market_hours`, `get_server_info`）做内存缓存（30s TTL）。

### 2. 0 slots（瞬时打满 120/min）

业务 tool **立即** raise `SchwabRateLimitError`，无 `retry_after_seconds` 或为 0。

- **服务端原因**：本机 token-bucket 容量打满；server 不阻塞而立即 raise，把节流决策交给 agent（避免阻塞别的并发 tool）。
- **agent 端处置**：实施指数退避重试（1s / 2s / 4s）；连续 3 次仍 raise → 告诉用户并把并发降下来。

### 3. `Retry-After` 头缺失

Schwab 返回 429 但响应里没有 `Retry-After` header（罕见）。

- **服务端兜底**：schwab-py 内部默认 **指数退避**（1s / 2s）兜底，agent 通常无需感知。
- **agent 端处置**：若 `SCHWAB_MAX_RETRIES` 跑完仍失败 → 当作普通 `SchwabRateLimitError` 处理；等 30-60s 后再试。
