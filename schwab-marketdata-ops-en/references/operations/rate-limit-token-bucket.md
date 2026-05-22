# Rate-limit token bucket (deep dive)

> **Status: placeholder.** This English stub is a skeleton mirror of
> the Chinese source, kept in sync for structural parity (heading
> count, link graph) but with bodies still pending high-quality
> translation. See the linked Chinese version below for the full
> content; please open an issue or PR to upgrade this file to a
> complete translation.

## Abstract

Implementation deep dive of the local token bucket + sliding window, plus tuning strategies for `SCHWAB_RATE_LIMIT_PER_MIN`.

## Source

For full content, see the Chinese version:
[`../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md`](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md).

## Schwab 官方限流

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## server 实现：token-bucket

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## 为什么不用 `asyncio.Semaphore`

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## 配置

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## Tuning strategy

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## 监控字段

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## 故障预案

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## What not to do

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._

## References

_Translation in progress — see the [Chinese version](../../../schwab-marketdata-ops/references/operations/rate-limit-token-bucket.md) for full content._
