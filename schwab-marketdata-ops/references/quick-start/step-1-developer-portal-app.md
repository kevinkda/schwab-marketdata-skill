# Quick Start — Step 1: Register a Schwab Developer Portal app

> **目标**：在 Schwab Developer Portal 创建一个 **Market Data Production**
> app，拿到 `App Key` 与 `App Secret` 两条凭证。这是后续所有步骤的前置。

## 前置条件

- [ ] 已注册 Schwab 个人账户（不是 Schwab Bank — 是 Brokerage 账户）
- [ ] 浏览器能访问 <https://developer.schwab.com>（部分公司网络会拦）
- [ ] 已仔细阅读
      <https://www.schwab.com/legal/terms> 与
      <https://developer.schwab.com/legal>，理解 Market Data 是
      **non-redistributable**（不可再分发）。

## 操作步骤

1. 浏览器打开 <https://developer.schwab.com/dashboard/apps>，用 Schwab
   Brokerage 账号登录。
2. 点 **Create App**。
3. 填写表单：
   - **App Name**：取个有辨识度的名字（建议形如
     `marketdata-personal-<your-handle>`）。一旦创建无法改名，但可删
     了重建。
   - **App Description**：单行用途描述，例如
     `Personal market-data research; private use only`。
   - **Callback URL**：
     - **login_flow**（默认）→ `https://127.0.0.1:8182`
     - **manual_flow**（headless / SSH-only）→ `https://127.0.0.1`
   - **API Product**：勾选 **Market Data Production**（必须；不要勾
     Trader API，本 skill 与 MCP 都不调用 Trader API）。
4. 提交后等 Schwab 审核（通常 1-3 个工作日，状态由 `Pending` →
   `Approved` 即可使用）。
5. App 进入 `Approved` 状态后，进入 app 详情页：
   - 点 **App Key**：复制（约 32 字符的字母数字串）。
   - 点 **App Secret** → **View**：复制（约 16 字符）。

## 期望产出

- App 状态 = `Approved`
- App Key（32 字符）已复制到剪贴板或临时安全笔记
- App Secret（16 字符）已复制到剪贴板或临时安全笔记
- Callback URL 与未来 `.env` 的 `SCHWAB_CALLBACK_URL` 字符级一致

## 验证清单

- [ ] App 详情页 `Status: Approved`（非 `Pending` / `Suspended`）
- [ ] App Key 长度 ≈ 32，全部字母数字
- [ ] Callback URL 已记录到剪贴板或安全位置
- [ ] 可访问 <https://developer.schwab.com/dashboard/apps>，本 app 可见

## 常见错误

| 现象 | 原因 / 处置 |
| ---- | ----------- |
| App 状态卡在 `Pending` 超过 5 工作日 | Schwab 审核积压；用 app 详情页的 Contact 通道催办 |
| 没有 **Market Data Production** 选项 | 个人 Brokerage 账号才有此 product；Schwab Bank-only 账号不行 |
| 注册成功但 OAuth 时 `unsupported_response_type` | 该 app 没真正激活 Market Data Production product；删 app 重建并确保勾选 |
| Callback URL 上写了 trailing slash 但 `.env` 没写（或反之） | 必须**字符级一致**；下一步会用 `--dry-run` 提前验证 |

## 下一步

→ [Step 2: Credentials & .env setup](step-2-credentials-env.md)

## 参考

- 上游 OAuth 流程深度解析：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
- ToS 关键节选：[`../tos-snapshot.md`](../tos-snapshot.md)
- 凭证泄露应急 runbook：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
