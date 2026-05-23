# Troubleshooting — `SchwabAuthError` (legacy redirect)

> This file is preserved for backward compatibility with old
> references; the content has been reorganized into the
> [`troubleshooting/`](troubleshooting/) subdirectory.

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/troubleshooting-auth.md`](../../schwab-marketdata-ops/references/troubleshooting-auth.md).

## New locations

Split per reason into individual files for precise routing:

| reason                              | Child file                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| `refresh_token_expired_soon`        | [`troubleshooting/auth-refresh-expiring-soon.md`](troubleshooting/auth-refresh-expiring-soon.md) |
| `refresh_token_expired`             | [`troubleshooting/auth-refresh-expired.md`](troubleshooting/auth-refresh-expired.md)             |
| `token_not_initialized`             | [`troubleshooting/auth-token-not-initialized.md`](troubleshooting/auth-token-not-initialized.md) |
| `token_corrupted`                   | [`troubleshooting/auth-token-corrupted.md`](troubleshooting/auth-token-corrupted.md)             |
| `insecure_token_perms`              | [`troubleshooting/auth-insecure-perms.md`](troubleshooting/auth-insecure-perms.md)               |
| `callback_url_mismatch`             | [`troubleshooting/auth-callback-url-mismatch.md`](troubleshooting/auth-callback-url-mismatch.md) |

## Entry point

Main entry (routing table + decision flow):
[`troubleshooting/auth-overview.md`](troubleshooting/auth-overview.md)

TokenState 4-state explainer:
[`troubleshooting/auth-token-states.md`](troubleshooting/auth-token-states.md)
