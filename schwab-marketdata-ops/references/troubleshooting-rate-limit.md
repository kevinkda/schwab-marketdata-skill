# Troubleshooting — `SchwabRateLimitError` (legacy redirect)

> 本文件为兼容旧引用而保留，内容已重组到
> [`troubleshooting/`](troubleshooting/) 子目录。

## 新位置

按症状拆分到独立子文件：

| 症状                                 | 子文件                                                                              |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| Schwab 服务端 429                     | [`troubleshooting/rate-limit-429.md`](troubleshooting/rate-limit-429.md)            |
| 本机 token-bucket 0 slots             | [`troubleshooting/rate-limit-token-bucket-empty.md`](troubleshooting/rate-limit-token-bucket-empty.md) |
| `rate_limit_warning` 预警（仍成功）   | [`troubleshooting/rate-limit-warning-stderr.md`](troubleshooting/rate-limit-warning-stderr.md) |
| 429 缺 `Retry-After` 头（罕见）        | [`troubleshooting/rate-limit-no-retry-after.md`](troubleshooting/rate-limit-no-retry-after.md) |

## 入口

总入口（路由表 + decision flow）：
[`troubleshooting/rate-limit-overview.md`](troubleshooting/rate-limit-overview.md)

token-bucket 实现深度（用于调优）：
[`operations/rate-limit-token-bucket.md`](operations/rate-limit-token-bucket.md)
