# Troubleshooting — 429 missing `Retry-After` header

Schwab 返回 `429 Too Many Requests`，但响应里没有 `Retry-After` HTTP
头。**罕见**，但需要兜底。

## Symptom

server.log 出现：

```text
2025-05-23 10:42:18,123 WARNING schwab returned 429 with no Retry-After header
2025-05-23 10:42:19,400 INFO    falling back to exponential backoff: sleep 1s
2025-05-23 10:42:20,800 INFO    retry attempt 2, sleeping 2s
```

最终业务 call 可能成功也可能失败：

- 成功：透明，agent 不会感知
- 失败：返回 `SchwabRateLimitError(retry_after_seconds=<schwab-py 默认>)`

## Root cause

上游边缘节点 / WAF 改写 header；或网络中间设备把头剥掉了。Schwab 服务
端按 RFC 7231 应当返回 `Retry-After`，但实际偶尔会丢。

## server 端兜底

schwab-py 内部默认走 **指数退避**（1s / 2s / 4s）兜底，所以 agent 通常
不会感知到这一情况。`SCHWAB_MAX_RETRIES`（默认 2）次仍失败才向上传。

## 检查命令

```bash
# 看服务器日志确认 schwab-py 是否在 retry
grep -E "(429|Retry-After|retry attempt)" \
    ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | tail -50
```

## 修复策略

无需 agent 干预；如果 `SCHWAB_MAX_RETRIES` 跑完仍失败 → 当作普通
`SchwabRateLimitError` 处理（参考 [`rate-limit-429.md`](rate-limit-429.md)）。

## 验证

```bash
# 5 分钟后看 health：recent_error_count_24h 不再增长
uv run python -m schwab_marketdata_mcp.health
```

## 不要做的事

- **不要** 在 agent 侧实现自己的指数退避覆盖 server 兜底 —— 重复退避
  会让等待时间不必要地长。
- **不要** 把 `SCHWAB_MAX_RETRIES` 调到很大（如 10）—— 退避会指数放大，
  最终等几分钟比直接告诉用户慢得多。

## 参考

- 普通 429：[`rate-limit-429.md`](rate-limit-429.md)
- token-bucket 实现：[`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- 限流总览：[`rate-limit-overview.md`](rate-limit-overview.md)
