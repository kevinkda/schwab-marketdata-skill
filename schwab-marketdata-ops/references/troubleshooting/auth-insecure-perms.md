# Troubleshooting — `SchwabAuthError(reason="insecure_token_perms")`

token.json 权限不是 `600` 或父目录不是 `700`，server 拒绝启动。

## Symptom

- server 启动时 stderr 出现 `chmod 600 ...` / `chmod 700 ...` hint
- `health_check()` 返回 `token_state == "insecure_perms"`
- 业务 call 返回 `{"error":"SchwabAuthError","reason":"insecure_token_perms"}`

## Root cause（5 种典型）

1. `umask` 不是 `077`，schwab-py 第一次写文件时权限自然就不对
2. 用 `cp -p` 从别处复制过来时**目标**权限是 default（`644`）
3. `rsync` 同步未加 `--perms`
4. macOS 上从 NTFS / FAT32 外置盘恢复 token（FAT32 不支持 unix 权限）
5. 别的进程（IDE / file manager）以管理员权限改写了文件

## 检查命令

### Linux

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -c '%a %n' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"
# 期望：
#   600 ~/.local/state/schwab-marketdata-mcp/token.json
#   700 ~/.local/state/schwab-marketdata-mcp
```

### macOS

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -f '%A %N' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"
```

## 修复命令

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
chmod 700 "$(dirname "$TOKEN_PATH")"
chmod 600 "$TOKEN_PATH"
```

## 验证命令

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# 期望：token_state == "valid"
```

## 防止重复发生

把 `umask 077` 加到 shell rc：

```bash
# ~/.zshrc 或 ~/.bashrc
umask 077
```

或者在跑 server 的 shell 里临时设置：

```bash
umask 077 && uv run schwab-marketdata-mcp
```

## 为什么 server 这么严？

token.json 含 refresh_token，泄露后攻击者**可以代表你**调任何
Market Data API 7 天 + （如果他们及时刷新）继续 rotate。Linux / macOS
的标准最小权限就是 `600`（仅拥有者读写），没有理由放宽。

## 不要做的事

- **不要** `chmod 644` 或 `chmod 666` 试图绕过检查 —— server 启动时
  会再检查。
- **不要** 把 `--no-perm-check` 这类 flag 加到 server CLI（**没有**
  这样的 flag，是有意设计）。

## 参考

- TokenState 4 种：[`auth-token-states.md`](auth-token-states.md)
- 凭证泄露应急：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- OAuth 流程：[`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
