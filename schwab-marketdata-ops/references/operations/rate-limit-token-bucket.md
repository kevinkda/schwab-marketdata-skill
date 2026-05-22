# Operations — token-bucket deep dive

> 服务端限流的详细行为、配置方式、调优建议。补充
> [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
> 的 trouble-shooting 视角。

## Schwab 官方限流

Schwab 不公布精确每账户 quota。社区测算 **~120 req/min/user** for
Market Data Production。官方文档只说 "rate limits apply, see
`Retry-After`"，没有具体数字。

`schwab-marketdata-mcp` 默认配置 `SCHWAB_RATE_LIMIT_PER_MIN=120` 与
社区测算保持一致。

## server 实现：token-bucket

```text
                    ┌─────────────────────┐
                    │ token-bucket        │
                    │ capacity = 120      │
  request ─────▶ acquire 1 slot ─┬──▶ schwab-py call
                    │             │
                    │             └──▶ slot expires after 60s
                    │                 (sliding window)
                    └─────────────────────┘
```

具体行为：

- **bucket capacity** = `SCHWAB_RATE_LIMIT_PER_MIN`（默认 120）
- 每个请求消耗 1 slot，slot 在 **60 秒后**自动恢复（**滑动窗口**，
  不是每分钟 reset）
- 当剩余 slot < 20 时，server 写一条结构化 WARNING 到 stderr：
  `{"event":"rate_limit_warning","remaining":N}`
- 当剩余 slot == 0 时，下一个 call **立即 raise**
  `SchwabRateLimitError`，**不阻塞**

## 为什么不用 `asyncio.Semaphore`

| 维度                | `asyncio.Semaphore`                         | **token-bucket**（当前选型）      |
| ------------------- | ------------------------------------------- | --------------------------------- |
| 拿不到 slot 时       | `await acquire()` 阻塞                       | 立即 raise                          |
| retry sleep 期间     | 持有 slot，**阻塞**别的并发 tool             | **释放** slot 让别的 tool 通过      |
| 并发场景            | 多 tool 串行化                               | 多 tool 并行                        |
| MCP timeout 风险    | 长 await 可能 ≥ 30s timeout，breakprotocol   | 立即 raise，agent 自己 backoff       |
| 节流决策            | server 决定（阻塞）                          | agent 决定（重试节奏）              |

**关键收益**：单个慢 tool（被限流退避中）**不阻塞**别的并发 tool
（例如 health_check / 别的 quote 调用）。

## 配置

`.env` 字段：

```bash
# 本机限流上限；建议 80-120
SCHWAB_RATE_LIMIT_PER_MIN=120

# 自动重试次数（429 / 5xx），默认 2
SCHWAB_MAX_RETRIES=2

# 测试时设 0 让失败立即可见
# SCHWAB_MAX_RETRIES=0
```

## 调优策略

### 单 agent 单 server

```bash
SCHWAB_RATE_LIMIT_PER_MIN=100   # 比 Schwab 默认严，留 20% 余量
```

让本机先于 Schwab 触发限流，避免被服务端记账（持续超限会触发更严的
服务端限流甚至临时封锁）。

### 多 agent / 多 Cursor 窗口连同一 server

token-bucket 是 server 进程级共享。所以多 agent 加起来 ≤ 120 仍 OK：

```bash
SCHWAB_RATE_LIMIT_PER_MIN=120   # 全部 agent 共享 120
```

### 多 agent / 各跑各的 server

每个 server 进程都有独立 bucket，但 Schwab 服务端配额仍共享。所以：

```bash
# 每个 server 单独：
SCHWAB_RATE_LIMIT_PER_MIN=60   # 两个 server 共享 120
```

### 高频 batch 任务

```bash
SCHWAB_RATE_LIMIT_PER_MIN=80   # 留更多 headroom 给意外
SCHWAB_MAX_RETRIES=3           # 更多 retry，提高成功率
```

## 监控字段

`health_check()` 的 3 个限流相关字段：

| 字段                              | 含义                                              |
| --------------------------------- | ------------------------------------------------- |
| `rate_limit_remaining_per_min`    | 当前 bucket 剩余 slot；< 20 应当注意               |
| `recent_error_count_24h`          | 过去 24h 累计 `Schwab*Error`（含所有类型）         |
| `last_request_status`             | 最近一次业务 call 的结果                           |

## 故障预案

| 现象                                | 建议                                                       |
| ----------------------------------- | ---------------------------------------------------------- |
| `recent_error_count_24h` 持续上涨    | 监测 `SCHWAB_RATE_LIMIT_PER_MIN` 是否设得过高              |
| 同时多个 agent 都报 0 slots          | 把 `SCHWAB_RATE_LIMIT_PER_MIN` 切半                          |
| `rate_limit_warning` 每分钟出现     | 调用模式不健康，参考 [`../troubleshooting/rate-limit-warning-stderr.md`](../troubleshooting/rate-limit-warning-stderr.md) |

## 不要做的事

- **不要** 把 `SCHWAB_RATE_LIMIT_PER_MIN` 调到 > 120。
- **不要** 让 agent 自己实现 retry 时绕过 server 的 retry 计数（叠加退
  避会让等待时间指数放大）。
- **不要** 多 agent 各启 server 进程绕过 bucket —— Schwab 服务端配额
  仍是单账户共享。

## 参考

- 限流 trouble-shooting：[`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
- 0 slots 处置：[`../troubleshooting/rate-limit-token-bucket-empty.md`](../troubleshooting/rate-limit-token-bucket-empty.md)
- Architecture：[`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)
