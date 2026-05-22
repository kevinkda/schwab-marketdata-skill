# Troubleshooting — `SchwabTransientError`

Schwab 服务端 5xx / 网络抖动；schwab-py 已经按 `SCHWAB_MAX_RETRIES`
（默认 2）次指数退避重试仍失败。

## Symptom

```text
{
  "error": "SchwabTransientError",
  "status_code": <5xx 或 4xx 非 401/429>,
  "message": "..."
}
```

## Root cause

| 类别                          | 含义                                                                                |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| **5xx (500/502/503/504)**     | Schwab 服务端故障 / 网关超时；schwab-py 已按 `SCHWAB_MAX_RETRIES` 次指数退避重试仍失败 |
| **非 401/429 的 4xx (400/404)** | 通常是 Pydantic 没拦下来的边角输入（某字段 Schwab 服务端比文档更严格）                |

## 修复策略

### 5xx：等待 + 监控

- 等 30-60 秒后**重试一次**
- 如果 30 分钟内 ≥ 3 次同类错误 → 告诉用户 Schwab 那边可能有故障
- 查 [Schwab Developer Portal Status](https://developer.schwab.com/) 公告

```python
import asyncio

async def call_with_5xx_retry(call, max_attempts=3):
    for attempt in range(max_attempts):
        result = await call()
        if result.get("error") != "SchwabTransientError":
            return result
        if result.get("status_code", 0) < 500:
            return result   # 4xx 别重试，参数问题
        await asyncio.sleep(30 * (attempt + 1))
    return result
```

### 4xx 非 401/429

- 对照 [`validation-overview.md`](validation-overview.md) 与 12 tool reference
  检查参数
- 用 `--dry-run` 模式预跑（schwab-py 部分支持）
- 仍无解 → 在 `schwab-marketdata-mcp` 仓库提 issue（附 stderr log
  - 调用 args，先 mask 任何 token / Bearer）

## 检查命令

```bash
# 看 server.log 里 schwab-py 的具体错误
tail -50 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep -E "(status_code|SchwabTransientError)"
```

## 验证

```bash
# 等几分钟，看 health 中错误计数是否平稳
sleep 300
uv run python -m schwab_marketdata_mcp.health \
    | jq '.recent_error_count_24h'
```

连续 3 次重试有至少 1 次成功 = 临时抖动；持续失败 = 真故障。

## 区分真故障 vs 临时抖动

| 维度                        | 临时抖动              | 真故障                          |
| --------------------------- | --------------------- | ------------------------------- |
| 5 分钟内 retry 次数          | 1-2 次                | ≥ 3 次                          |
| 错误间隔                     | 散乱                  | 持续每分钟 ≥ 1                   |
| 业务 call 总数 vs 错误数     | 错误率 < 1%           | 错误率 > 5%                      |
| 影响所有 tool 还是单个        | 通常单个              | 通常全部                         |
| Schwab status page 公告      | 无                    | 通常有                           |

## 不要做的事

- **不要** 在 5xx 上无限重试 —— 退避至少 30s，最多 3 次。
- **不要** 把 4xx 当成 transient（4xx 是参数问题，不会自愈）。
- **不要** 在 agent 自己实现 retry 时绕过 `SCHWAB_MAX_RETRIES` —— 那
  会让 server 端的 retry 与 agent 端的 retry 叠加，等待时间指数放大。

## 参考

- 错误体系总览：[`../error-recovery.md`](../error-recovery.md)
- Validation 错误：[`validation-overview.md`](validation-overview.md)
- Schwab status page：<https://developer.schwab.com/>
