# Troubleshooting — `SchwabAuthError`

针对每个 `reason` 给出 5 段标准化处置：**Symptom / Root cause / 检查命令 / 修复命令 / 验证命令**。先用 `health_check()` 看 `token_state`，再到下面对应小节执行。

---

## 1. `reason="refresh_token_expired_soon"`

- **Symptom**：`health_check()` 返回 `token_expires_in_days < 0.5`；server 启动时 stderr 出现 warning；cron `health.py` 在 `~/Desktop/SCHWAB_REAUTH_NEEDED.md` 落地。
- **Root cause**：refresh_token **7 天绝对寿命**即将到期（< 12 小时窗口）。这是 Schwab OAuth 的硬限制，无法绕过。
- **检查命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health
  # 看 token_expires_in_days 字段
  ```
- **修复命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.auth login_flow
  # 远程 / SSH-only：用 manual_flow
  uv run python -m schwab_marketdata_mcp.auth manual_flow
  ```
- **验证命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health
  # 期望：exit 0，token_state == "valid"，token_expires_in_days >= 6.5
  ```

---

## 2. `reason="refresh_token_expired"`

- **Symptom**：业务 tool 调用返回 `{"error":"SchwabAuthError","reason":"refresh_token_expired"}`；schwab-py 内部刷新失败抛 `invalid_grant`。
- **Root cause**：refresh_token 7 天窗口已过期，已被 Schwab 服务端撤销，**不可挽救**，必须重新走 OAuth。
- **检查命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health
  # token_state 仍可能是 "valid"（本地文件未损坏），但任何业务 call 都会失败
  ```
- **修复命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.auth login_flow
  ```
- **验证命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health   # exit 0
  # 然后用 mcp client 调一次 get_quote("VOO") 确认 200 OK
  ```

---

## 3. `reason="token_not_initialized"`

- **Symptom**：首次启动 server 或刚 `rm token.json`；`health_check()` 返回 `token_state == "missing"`。
- **Root cause**：默认 token 路径下没有 `token.json`，OAuth 从未走过 `login_flow`。
- **检查命令**：
  ```bash
  ls -la "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/"
  # 应看到 token.json；若不存在则未初始化
  ```
- **修复命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.auth login_flow
  ```
- **验证命令**：
  ```bash
  ls -l "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
  # 应看到 -rw------- (chmod 600)
  uv run python -m schwab_marketdata_mcp.health   # exit 0
  ```

---

## 4. `reason="token_corrupted"`

- **Symptom**：`health_check()` 返回 `token_state == "malformed"`；server 启动时报 `JSONDecodeError` 或缺关键字段。
- **Root cause**：`token.json` 被部分写入、被外部工具篡改、磁盘损坏，或 schwab-py 升级后字段不兼容。
- **检查命令**：
  ```bash
  cat "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json" | python -m json.tool
  # 若报错则确认损坏
  ```
- **修复命令**：
  ```bash
  TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
  cp "$TOKEN_PATH" "${TOKEN_PATH}.bak.$(date +%s)"   # 先备份
  rm "$TOKEN_PATH"
  uv run python -m schwab_marketdata_mcp.auth login_flow
  ```
- **验证命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health   # exit 0, token_state == "valid"
  ```

---

## 5. `reason="insecure_token_perms"`

- **Symptom**：server 启动时拒绝运行，stderr 出现 `chmod 600 …` / `chmod 700 …` hint；`health_check()` 返回 `token_state == "insecure_perms"`。
- **Root cause**：`token.json` 文件权限不是 `600`，或父目录不是 `700`（可能被 `umask` 修改、被 `cp -p` 复制丢失权限、或被 `rsync` 同步过来）。
- **检查命令**：
  ```bash
  TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
  stat -c '%a %n' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"
  # 期望：600 …/token.json   700 …/schwab-marketdata-mcp
  ```
- **修复命令**：
  ```bash
  TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
  chmod 700 "$(dirname "$TOKEN_PATH")"
  chmod 600 "$TOKEN_PATH"
  ```
- **验证命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.health   # exit 0
  ```

---

## 6. `reason="callback_url_mismatch"`

- **Symptom**：`login_flow` 启动浏览器，OAuth 重定向后 schwab-py 收到的 redirect URL 与 `.env` 里 `SCHWAB_CALLBACK_URL` 不一致；server 启动时直接 raise。
- **Root cause**：`.env` 里 `SCHWAB_CALLBACK_URL` 与 [Schwab Developer Portal](https://developer.schwab.com/) 上注册的 App Callback URL **不完全相等**（差一个 `/`、`http` vs `https`、端口号、子域名都算不一致）。
- **检查命令**：
  ```bash
  grep -E '^SCHWAB_CALLBACK_URL=' /path/to/schwab-marketdata-mcp/.env
  # 然后到 https://developer.schwab.com/dashboard/apps 看注册值
  ```
- **修复命令**：编辑 `.env`，把 `SCHWAB_CALLBACK_URL` 改成与 Developer Portal **逐字符相同**（含 trailing slash 与否）。
  ```bash
  # 修改后重启 server
  pkill -f schwab_marketdata_mcp || true
  ```
- **验证命令**：
  ```bash
  uv run python -m schwab_marketdata_mcp.auth login_flow
  # 浏览器走完一圈不再报 callback mismatch
  uv run python -m schwab_marketdata_mcp.health   # exit 0
  ```

---

## 不要做的事

- **不要** echo 任何 `Bearer …` header 到日志或对用户可见的输出（即便错误信息里出现，先 mask 再展示）。
- **不要** 在 `SchwabAuthError` 上静默重试，agent 必须停下让用户走 `login_flow`。
- **不要** 凭证泄露后用 `git push --force` 抹历史；走 `credentials-rotate-runbook.md` 的安全分支 + PR 审查流程。
