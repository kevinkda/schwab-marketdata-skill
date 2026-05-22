# Operations — Multi-machine & multi-account

> 当你想在 ≥ 2 台机器或 ≥ 2 个 Schwab 账户上跑 schwab-marketdata-mcp 时
> 必须知道的设计约束。

## TL;DR

- **多机器同账户**：每台机器**独立**走一次 OAuth；**不要**复制 token.json。
- **多账户单机器**：用 `--config-dir` 指定不同 token 目录；每个账户单独
  `.env` + 单独 OAuth。
- **多机器 + 多账户**：组合上面两条；笛卡尔积每个 (machine, account)
  各走一次 OAuth。

## 为什么不能复制 token.json 跨机？

`refresh_token` 是 **rotate-on-use**：每次刷新都签发新的、旧的立即失效。
所以：

```text
机器 A：access_token AT₁ + refresh_token RT₁
        ↓ 80 分钟后自动 refresh
       AT₂ + RT₂（旧 RT₁ 立即失效）

机器 B（复制了 token.json）：
       仍持有 AT₁ + RT₁ → 试图刷新 → invalid_grant → 全部失败
```

实测 Schwab 也会对同一 refresh_token 在不同 IP 上的请求做行为分析，
持续触发会**临时封锁账户**。

## 多机器同账户的正确做法

### 第一台机器

```bash
cd /path/to/schwab-marketdata-mcp
uv run python -m schwab_marketdata_mcp.auth login_flow
# 写到默认 ~/.local/state/schwab-marketdata-mcp/token.json
```

### 第二台机器

同样跑 OAuth，**用同一 Schwab 账号登录**：

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow
```

⚠️ 第二台机器走完 OAuth 后，**第一台机器的 refresh_token 会失效吗？**

**不一定**。Schwab 的 OAuth flow 在 token endpoint 是**幂等签发**：每次
新 OAuth 都签发独立的 refresh_token，互不影响。两台机器各持有独立的
RT，可以并存。但是：

- 任一台机器**刷新**时，它**自己的** RT rotate；不影响另一台。
- 两台机器**同时**调 API 时，Schwab 会按账户级配额合算（120 req/min
  共享）。

## 多账户单机器

每个账户独立的 token 目录与 `.env` 文件：

### 目录结构

```text
~/.local/state/
├── schwab-marketdata-mcp/             # 默认账户 A
│   └── token.json
├── schwab-marketdata-mcp-account-b/   # 账户 B
│   └── token.json
└── schwab-marketdata-mcp-account-c/   # 账户 C
    └── token.json
```

### 每个账户独立 OAuth

```bash
# 账户 A（默认目录）
uv run python -m schwab_marketdata_mcp.auth login_flow

# 账户 B
uv run python -m schwab_marketdata_mcp.auth login_flow \
    --config-dir ~/.local/state/schwab-marketdata-mcp-account-b

# 账户 C
uv run python -m schwab_marketdata_mcp.auth login_flow \
    --config-dir ~/.local/state/schwab-marketdata-mcp-account-c
```

注意 `--config-dir` 必须落在 allow-list 子目录（`~/.local/state` 或
`~/.config`，详见 [`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)）。

### `.env` 怎么处理？

每个账户**Developer Portal app 不同** → App Key / Secret / Callback URL
不同。建议**每个账户一个独立的 schwab-marketdata-mcp checkout**：

```text
~/code/kevinkda/schwab-marketdata-mcp-A/    # checkout 1，.env A
~/code/kevinkda/schwab-marketdata-mcp-B/    # checkout 2，.env B
```

然后 `~/.cursor/mcp.json` 注册两个 entry：

```json
{
  "mcpServers": {
    "schwab-marketdata-A": {
      "command": "/abs/path/to/uv",
      "args": ["--directory", "/home/you/code/kevinkda/schwab-marketdata-mcp-A", "run", "schwab-marketdata-mcp"]
    },
    "schwab-marketdata-B": {
      "command": "/abs/path/to/uv",
      "args": ["--directory", "/home/you/code/kevinkda/schwab-marketdata-mcp-B", "run", "schwab-marketdata-mcp"]
    }
  }
}
```

## 健康巡检 cron

每个账户单独跑 health：

```cron
# 账户 A
0 */4 * * * cd /home/you/code/kevinkda/schwab-marketdata-mcp-A && /abs/uv run python -m schwab_marketdata_mcp.health

# 账户 B
30 */4 * * * cd /home/you/code/kevinkda/schwab-marketdata-mcp-B && /abs/uv run python -m schwab_marketdata_mcp.health
```

## 不要做的事

- **不要** 跨机器 `rsync` token.json —— rotate-on-use 不兼容。
- **不要** 在多账户场景共用同一个 `.env` —— App Key / Secret 不同。
- **不要** 把多个账户的 token 都存到默认目录 —— 必须用 `--config-dir`
  分开。
- **不要** 假设 Schwab 账户级 quota 是按 IP 划分的 —— 它是按
  account-key（Developer Portal 上 App 维度）划分的。

## 参考

- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- token 路径 allow-list：[`../concepts/architecture-overview.md`](../concepts/architecture-overview.md)
- 凭证泄露应急：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
