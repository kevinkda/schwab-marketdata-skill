# OAuth — Token lifecycle deep dive

> 把 access_token / refresh_token / OAuth code 的 **寿命** / **rotate
> 行为** / **过期处置** 整理在一处，方便排查。

## 三个 token 的生命周期

```text
                ┌────────────────────┐
                │  OAuth code        │  寿命：5 分钟（一次性）
                │  来自浏览器 redirect│  rotate：N/A（一次性）
                └─────────┬──────────┘
                          │ schwab-py 交换
                          ▼
   ┌──────────────────────────┐    ┌──────────────────────────┐
   │  access_token            │    │  refresh_token           │
   │  寿命：90 分钟            │    │  寿命：7 天绝对                  │
   │  rotate：每次刷新都换    │    │  rotate：每次刷新都换    │
   │  作用：业务 API 鉴权     │    │  作用：换新的 access_token │
   └──────────────────────────┘    └──────────────────────────┘
                          │                       ▲
                          │ 90 分钟到期或主动调用 │
                          ▼                       │
                ┌────────────────────────────────┘
                │   schwab-py 自动调 token endpoint
                │   POST refresh_token → 新 access_token + 新 refresh_token
                │   写回 token.json
                └─────▶ 直到 7 天总寿命到期 → 必须重新走 OAuth
```

## 关键约束

### Refresh token 是 7 天**绝对**寿命

- 不论你是否使用，从**首次签发**起 7 天后服务端 invalidate。
- 这是 Schwab OAuth 的**硬限制**，无法通过任何客户端方式延长。
- 自动化场景下你必须每 7 天**人**走一次 `auth login_flow`（无论
  `login_flow` 还是 `manual_flow`）。

### Rotate-on-use

每次刷新都签发**新**的 refresh_token 替换旧的：

| 时间点  | 状态                                                                            |
| ------- | ------------------------------------------------------------------------------- |
| t=0     | OAuth 完成；token.json 写入 RT₁（7 天有效，到 t=7d）、AT₁（90 min 有效，到 t=90m） |
| t=80m   | schwab-py 在下次业务 call 前刷新 → 写入 RT₂（仍 7d，到 t=7d，**不延长**）、AT₂      |
| t=7d    | RT 任何代际过期；任何业务 call 触发 `SchwabAuthError(reason="refresh_token_expired")` |
| 修复    | 用户跑 `auth login_flow` → 重新签发 RT，t' 重新归零                              |

注意 RT₂ 不会把 7 天总寿命续上。从你**第一次**走 OAuth 起，7 天就开始倒
计时。

### 你能复制 token.json 到另一台机吗？

**不能**：

1. rotate-on-use：A 机器刷新后 B 机器的 RT 立即失效。
2. Schwab 不公布 token 与 IP 的强绑定，但实测多机器并发用同一 token
   会被 Schwab 限速 / 临时封锁。

正确做法：每台机器走一次 OAuth；多账户同样。

### 7 天到期前的预警

`schwab_marketdata_mcp.health` 模块内置一个**桌面通知**机制：

- `token_expires_in_days < 12h` 且 token 状态非 `valid` → 落地
  `~/Desktop/SCHWAB_REAUTH_NEEDED.md` + 触发 OS 通知（macOS：
  notification center；Linux：notify-send critical）。
- 与 cron / launchd 配合（每 4h + 周日 20:00 + 周三 21:00），可提前
  ≥ 12h 提醒用户 reauthorize。

详见 [Quick Start Step 7](../quick-start/step-7-cron-launchd-setup.md)。

## token.json 字段

```json
{
  "creation_timestamp": 1716200000,
  "token": {
    "access_token": "...",            // 90 分钟
    "refresh_token": "...",           // 7 天
    "id_token": "...",                // schwab-py 1.5+
    "token_type": "Bearer",
    "expires_in": 1800,
    "expires_at": 1716201800,
    "scope": "api"
  }
}
```

`creation_timestamp` 是 schwab-py 写入的字段，用于 `health` 模块算
`token_age_days`。

## 健康巡检模型

```text
                 ┌────────────────────────────────────┐
                 │         health_check()             │
                 └────────┬───────────────────────────┘
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        token_state   token_age_days  token_expires_in_days
        (4 enum)      (since creation) (until 7-day expiry)
              │           │           │
              ▼           ▼           ▼
        ┌────────────────────────────┐
        │   决策表                   │
        │   见 troubleshooting/      │
        │   auth-token-states.md     │
        └────────────────────────────┘
```

## 7 天周期内反复刷新会被节流吗？

实测每 90 分钟自动刷一次（schwab-py 默认行为）不会被节流。但如果你**人为**
高频调 refresh（例如每分钟）会被 Schwab token endpoint 限流（typical
1 req / 60 s）。

agent 端**不要**手动 refresh —— schwab-py 在每次业务 call 前自动检查
expiry。

## 常见疑问

### Q: 我能不能用 `id_token` 作为长期凭证？

不能。`id_token` 只是身份声明（OIDC），不能换 access_token，不能调业务
API。

### Q: token.json 删了，我的旧 RT 会立即被 Schwab 失效吗？

不会。RT 在服务端的失效条件是：(1) 7 天到期，(2) 你在 Developer Portal
**Reset App Secret**，(3) Schwab 内部判断异常吊销。删本地 token.json 只
丢失本地状态。

### Q: 我能不能用 schwab-py 之外的方式刷 token？

技术上可以（标准 OAuth refresh_token grant + Basic Auth with App Key /
Secret），但这意味着你要自己实现 rotate-on-use 写回与并发安全。我们
强烈建议沿用 schwab-py 的实现。

## 参考

- TokenState 4 状态详解：[`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
- refresh_token 过期处置：[`../troubleshooting/auth-refresh-expired.md`](../troubleshooting/auth-refresh-expired.md)
- 健康巡检自动化：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
