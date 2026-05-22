# Tool reference — Meta family

`health_check` / `get_server_info` — 健康巡检与版本握手。**不消耗
Schwab 配额**（仅本地状态读取与可选 token 元数据校验）。

## 1. `health_check()`

无参数；返回 server 当前健康快照。

### 返回 schema

```text
{
  "server_version": "0.1.x",
  "token_state": "valid" | "missing" | "malformed" | "insecure_perms",
  "token_age_days": float | null,
  "token_expires_in_days": float | null,
  "last_request_status": "unknown" | "ok" | "error",
  "rate_limit_remaining_per_min": int,
  "recent_error_count_24h": int,
  "platform_supported": true
}
```

### 字段语义

| 字段                            | 含义                                                                    |
| ------------------------------- | ----------------------------------------------------------------------- |
| `server_version`                | MCP server 当前版本（与 `compatible_mcp_version` 比较的依据）              |
| `token_state`                   | `valid` / `missing` / `malformed` / `insecure_perms`（4 种），见下表          |
| `token_age_days`                | 距离 token 创建的天数（refresh 后会被刷新）                                |
| `token_expires_in_days`         | refresh_token 还有多少天到期；< 0.5 强烈建议立即 reauthorize                |
| `last_request_status`           | 最近一次业务 call 的结果（`ok` / `error` / `unknown`）                     |
| `rate_limit_remaining_per_min`  | 本机 token-bucket 当前剩余 slot（默认上限 120）                            |
| `recent_error_count_24h`        | 过去 24 小时累计 `Schwab*Error` 数（含所有类型）                           |
| `platform_supported`            | 当前 OS 是否支持（macOS 11+ / Linux 才 true）                             |

### `token_state` 4 种值的处置

| 值                | 处置                                                                                          |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `valid`           | ✅ 一切正常，可以继续业务调用                                                                  |
| `missing`         | `token.json` 不存在；走 `auth login_flow` 初始化                                              |
| `malformed`       | JSON 损坏 / 字段缺失；备份后重新 OAuth                                                          |
| `insecure_perms`  | 权限不是 `600` / `700`；执行 `chmod 600 token.json` 与 `chmod 700 $(dirname token.json)`     |

完整对照表见 [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)。

### 调用示例

```text
health_check()
```

### 何时调

- **每次 skill 激活后**：先 `get_server_info`（版本握手），再
  `health_check`（token 体检）。
- **每个 playbook 开头**：作为 pre-flight 的一部分。
- **遇到 `SchwabAuthError` 时**：先 health 看 token_state，再决定是否
  reauthorize。
- **cron / launchd 巡检**：自动化巡检（详见 Quick Start Step 7）。

## 2. `get_server_info()`

无参数；返回 server 元数据，**与 token 状态无关**（即使 token 失效也能调）。

### 返回 schema

```text
{
  "server_version": "0.1.x",
  "mcp_sdk_version": "1.x.x",
  "schwab_py_version": "1.5.1",
  "supported_tools": [
    "get_quote",
    "get_quotes",
    "get_price_history",
    "get_option_chain",
    "get_option_expiration_chain",
    "get_market_hours",
    "get_market_hour_single",
    "get_movers",
    "search_instruments",
    "get_instrument_by_cusip",
    "health_check",
    "get_server_info"
  ],
  "platform_supported_v1": ["macos>=11", "linux"]
}
```

### 字段语义

| 字段                       | 含义                                                                      |
| -------------------------- | ------------------------------------------------------------------------- |
| `server_version`           | 用于 skill `compatible_mcp_version` 范围匹配                                |
| `mcp_sdk_version`          | 当前 MCP Python SDK 版本                                                   |
| `schwab_py_version`        | 当前 schwab-py 版本                                                        |
| `supported_tools`          | 12 个 tool 的字符串名（agent 可用此做 capability discovery）                 |
| `platform_supported_v1`    | v0.1 支持的 OS 列表                                                        |

### 何时调

- **skill 第一次激活时**：必须调一次，用于版本握手。如果
  `server_version` 不在 `compatible_mcp_version` 范围内，**立即停下**，
  告诉用户升级 server 或 skill。
- **首次注册到新客户端时**：用于发现 12 个 tool 都正确暴露。

## 何时用哪一个？

| 场景                                       | 用                  |
| ------------------------------------------ | ------------------- |
| skill 激活第一步（版本握手）                | `get_server_info`   |
| token 状态体检                              | `health_check`      |
| 调试某次 call 是否真的连接成功               | 二者都调一次         |
| cron / launchd 自动巡检                     | `health_check`（够） |
| 想要 capability discovery（列出所有 tool）   | `get_server_info`   |

## 不要做的事

- **不要** 把 `health_check` 用作 keepalive（频率应当 ≥ 4h，更频繁无意义）。
- **不要** 把 `get_server_info` 当 health 用 —— 它不读 token 状态。
- **不要** 在错误日志里直接 dump health_check 全文 —— 含 `token_age_days`
  这种 metadata，可推断账户使用模式；先脱敏。

## 参考

- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- TokenState 详解：[`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
- 健康巡检自动化：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
