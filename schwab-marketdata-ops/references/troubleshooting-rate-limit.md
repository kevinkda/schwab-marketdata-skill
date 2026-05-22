# Troubleshooting — `SchwabRateLimitError` & 限流相关

4 个常见症状 + 处置。完整的 token-bucket 行为详解见 `rate-limits-and-paging.md`。

---

## 1. Schwab `429 Too Many Requests`

- **Symptom**：业务 tool 返回 `{"error":"SchwabRateLimitError","retry_after_seconds":<int>,"current_window_used":<int>}`。
- **Root cause**：你（或 agent）在 ~120 req/min/user 配额上撞墙。schwab-py 已经按 `Retry-After` header 自动重试 `SCHWAB_MAX_RETRIES`（默认 2）次，仍未成功。
- **检查命令**：
  ```bash
  # 看 server 端最近的限流统计
  echo '{"method":"health_check","params":{}}' | <your mcp client>
  # 关注 rate_limit_remaining_per_min（剩余 slot）
  ```
- **修复策略**：
  1. 立刻：等待 `retry_after_seconds` 后重试一次；连续两次失败 → 告诉用户。
  2. 短期：把多次 `get_quote` 合并为一次 `get_quotes(symbols=[…])`（≤ 50）。
  3. 长期：在 server `.env` 调低 `SCHWAB_RATE_LIMIT_PER_MIN`（如 100），让本机限流先于 Schwab 触发，避免被服务端记账。
- **验证**：重试成功且 `health_check()` 中 `recent_error_count_24h` 不再增长。

---

## 2. token-bucket 0 slots（瞬时打满）

- **Symptom**：业务 tool **立即** 返回 `SchwabRateLimitError`，`retry_after_seconds == 0` 或缺失，且 stderr 没有出现 Schwab 的 `Retry-After` 痕迹。
- **Root cause**：本机 token-bucket 容量打满（同一分钟窗口内已发出 ≥ 120 个请求），server **不阻塞**而是立即 raise，把节流决策交给 agent。这是 `Semaphore` vs `token-bucket` 选型的一个有意设计（避免 retry sleep 阻塞别的 tool）。
- **检查命令**：
  ```bash
  # 在调用瞬间看 stderr 日志
  # 期望：之前应已出现 {"event":"rate_limit_warning","remaining":<20}
  ```
- **修复策略**：agent 端实施 **指数退避重试**：
  ```text
  attempt 1 fail → sleep 1s
  attempt 2 fail → sleep 2s
  attempt 3 fail → sleep 4s → give up，告诉用户
  ```
  并在下一次 batch 前把并发 / 频率降下来。
- **验证**：连续 3 次重试都不再立即 raise。

---

## 3. `rate_limit_warning` 出现在 stderr（剩余 < 20）

- **Symptom**：stderr 出现 `{"event":"rate_limit_warning","remaining":<20}` 但业务 call 仍成功。
- **Root cause**：本分钟内剩余 slot 已少于 20；这是预警，不是错误。
- **修复策略**：
  - 把多次单点 `get_quote` 改为一次 `get_quotes`（一次最多 50 symbol = 1 slot）。
  - 减少 `get_price_history` 在循环内的频次：考虑用大粒度（`MONTH` / `YEAR`）一次拿足，而不是按天循环。
  - playbook 编排：把 `get_market_hours` / `get_server_info` 这种高频 metadata 调用做内存缓存（30s TTL 足够）。
- **验证**：观察后续若干分钟内 warning 不再出现，且 `recent_error_count_24h` 持平。

---

## 4. `Retry-After` 头缺失

- **Symptom**：Schwab 返回 429 但响应里没有 `Retry-After` header（实际很罕见，但需有兜底）。
- **Root cause**：上游边缘节点 / WAF 改写 header；或网络层把头剥掉了。
- **服务端行为**：schwab-py 内部默认走 **指数退避**（1s / 2s / 4s）兜底，所以 agent 通常不会感知到这一情况。
- **检查命令**：
  ```bash
  # 看服务器日志确认 schwab-py 是否在 retry
  # 通常会有 "retry attempt N, sleeping Ns"
  ```
- **修复策略**：无需 agent 干预；如果 `SCHWAB_MAX_RETRIES` 跑完仍失败 → 当作普通 `SchwabRateLimitError`（症状 1）处理。
- **验证**：`health_check()` 中 `recent_error_count_24h` 在 5 分钟后不再增长。

---

## 不要做的事

- **不要** 在 `SchwabRateLimitError` 上立即重试同一调用 ≥ 3 次（触发更严的服务端封锁）。
- **不要** 把 `SCHWAB_RATE_LIMIT_PER_MIN` 调到 > 120（Schwab 服务端会先发飙）。
- **不要** 在多 agent 并发场景下假设各自独立，本机 token-bucket 是 server 进程级共享的；多 agent 加起来才是分钟配额。
