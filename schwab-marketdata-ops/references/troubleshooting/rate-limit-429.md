# Troubleshooting — Schwab `429 Too Many Requests`

服务端返回的 429 —— 你已经撞上 Schwab 的 ~120 req/min/user 配额墙。
schwab-py 已经按 `Retry-After` 头自动重试 `SCHWAB_MAX_RETRIES`（默认 2）
次仍未成功，把错误返回给 agent。

## Symptom

```text
{
  "error": "SchwabRateLimitError",
  "retry_after_seconds": 30,           // 服务端给的等待秒数
  "current_window_used": 120,
  "message": "Rate limit reached"
}
```

## Root cause

你（或你的 agent）在 ~120 req/min/user 配额上撞墙。schwab-py 已经按
`Retry-After` 头自动重试 `SCHWAB_MAX_RETRIES`（默认 2）次仍未成功。

## 检查命令

```bash
# 看 server 端最近的限流统计
echo '{"method":"health_check","params":{}}' | <your mcp client>
# 关注 rate_limit_remaining_per_min（剩余 slot）与 recent_error_count_24h
```

或在 stdio 命令行里：

```bash
(
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shell","version":"0.0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"health_check","arguments":{}}}'
) | uv run schwab-marketdata-mcp 2>/dev/null \
  | jq -c 'select(.id==2) | .result.content[0].text | fromjson'
```

## 修复策略

### 1. 立即（agent 行为）

```text
- 等待 retry_after_seconds 后重试一次
- 连续 2 次失败 → 告诉用户
- agent 实施指数退避：sleep 1s → 2s → 4s 后 give up
```

### 2. 短期（任务结构调整）

| 反模式                                  | 改成                                       |
| --------------------------------------- | ------------------------------------------ |
| 循环 `get_quote(SYM)` 调 N 次          | `get_quotes(symbols=[...])` 一次最多 50    |
| 循环 `get_price_history` 按天拉日 K    | 大粒度（`MONTH`/`YEAR`）一次拿足            |
| 反复调 `get_market_hours`              | agent 端做内存缓存，TTL 30s                |

### 3. 长期（配置调整）

```bash
# 在 .env 里调低本机限流，让本机先于 Schwab 触发：
SCHWAB_RATE_LIMIT_PER_MIN=80
```

让本机成为限流的第一道墙，避免被 Schwab 服务端记账（持续超限会触发
服务端的更严限流甚至临时封锁账户）。

## 验证

```bash
# 重试成功 + health_check 中 recent_error_count_24h 不再增长
uv run python -m schwab_marketdata_mcp.health
```

## 多 agent 并发的特殊注意

token-bucket 是 server **进程级**共享。如果你跑了 2 个 Cursor 窗口同时
连同一个 server，**两边加起来**才是分钟配额。建议：

- 单台机器同账户**只跑一个** server 进程
- 多 agent 想各跑各的 → 在 `.env` 里把 `SCHWAB_RATE_LIMIT_PER_MIN` 切
  半（如 60），让多 agent 之和仍 ≤ 120

## 不要做的事

- **不要** 立即重试同一调用 ≥ 3 次（触发更严封锁）。
- **不要** 假设 `Retry-After` 永远存在，参考
  [`rate-limit-no-retry-after.md`](rate-limit-no-retry-after.md)。
- **不要** 把 `SCHWAB_RATE_LIMIT_PER_MIN` 调到 > 120（Schwab 那边会先
  发飙）。

## 参考

- 限流总览：[`rate-limit-overview.md`](rate-limit-overview.md)
- token-bucket 深度：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 0 slots 立即 raise：[`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)
