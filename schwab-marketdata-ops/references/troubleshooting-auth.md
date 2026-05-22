# Troubleshooting — `SchwabAuthError` (legacy redirect)

> 本文件为兼容旧引用而保留，内容已重组到
> [`troubleshooting/`](troubleshooting/) 子目录。

## 新位置

按 reason 拆分到独立子文件，便于精确路由：

| reason                              | 子文件                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------- |
| `refresh_token_expired_soon`        | [`troubleshooting/auth-refresh-expiring-soon.md`](troubleshooting/auth-refresh-expiring-soon.md) |
| `refresh_token_expired`             | [`troubleshooting/auth-refresh-expired.md`](troubleshooting/auth-refresh-expired.md)             |
| `token_not_initialized`             | [`troubleshooting/auth-token-not-initialized.md`](troubleshooting/auth-token-not-initialized.md) |
| `token_corrupted`                   | [`troubleshooting/auth-token-corrupted.md`](troubleshooting/auth-token-corrupted.md)             |
| `insecure_token_perms`              | [`troubleshooting/auth-insecure-perms.md`](troubleshooting/auth-insecure-perms.md)               |
| `callback_url_mismatch`             | [`troubleshooting/auth-callback-url-mismatch.md`](troubleshooting/auth-callback-url-mismatch.md) |

## 入口

总入口（路由表 + decision flow）：
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md)

TokenState 4 状态详解：
[`troubleshooting/auth-token-states.md`](troubleshooting/auth-token-states.md)
