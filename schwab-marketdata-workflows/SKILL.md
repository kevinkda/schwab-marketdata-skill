---
name: schwab-marketdata-workflows
compatible_mcp_version: ">=0.1,<0.2"
language_directive: "Always respond to the user in Simplified Chinese (简体中文)."
required_workspace: "/opt/workspace/code/kevinkda/stock-personal"
description: |
  Use when the user asks to refresh summary.md, voo-qqq-tracker.md,
  watchlist.md, or run a shakeout-model snapshot, monthly watchlist scan,
  or option-chain research routine that depends on Schwab Market Data.
  Provides end-to-end playbooks that orchestrate multiple
  schwab-marketdata-mcp tools and write results back to project markdown
  files in the kevinkda/stock-personal repo.
  Use this skill instead of schwab-marketdata-ops when the task spans
  multiple tool calls and writes to markdown.
  Triggers on "update summary.md", "refresh watchlist", "shakeout
  snapshot", "VOO/QQQ tracker update", "刷新 summary",
  "更新 watchlist".
  对于以上场景使用本 skill；面向用户的所有回答必须使用简体中文。
---

# schwab-marketdata-workflows

> **License & ToS reminder** — Schwab Market Data 是 **不可再分发** 的。
> 本 skill 写入的每一份 markdown **必须** 留在
> `kevinkda/stock-personal` 私有仓库内。每个 playbook 在写入前会自动用
> 本机已认证的 `gh` CLI 校验仓库 `isPrivate == true`；校验失败则拒绝写入。

## 激活时第一步（必须执行）

```text
1. get_server_info()  — 校验 server_version 落在 compatible_mcp_version 范围
2. 校验 cwd 与 required_workspace 关系：
   - 当前 cwd 在 required_workspace 子树下 → 可读 + 可写
   - 否则 → 仅可读 target_files；禁止写入（防止误把数据落到其他仓库）
3. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   - 若返回 false / 无 gh CLI / 未登录 → 强烈建议用户人工确认；非交互场景下停下不写
```

## Playbook 选择表

| 用户意图                             | Playbook                                      |
| ------------------------------------ | --------------------------------------------- |
| 刷新 VOO/QQQ tracker                 | `playbooks/voo-qqq-tracker-update.md`         |
| 刷新 watchlist 快照（月度/事件触发） | `playbooks/watchlist-snapshot.md`             |
| 总结性 `summary.md` 重写             | `playbooks/summary-md-refresh.md`             |
| 期权链研究（单次深挖）               | `playbooks/option-chain-research.md`          |

## 通用约束（所有 playbook 必须遵守）

- **commit 前缀**：所有由本 skill 触发的 commit message 必须以
  `data(schwab):` 开头，便于事后审计。
- **不直接 commit 到 main**：在当前 feature/data 分支上 commit；如果当前
  cwd 在 main 分支，先 `git switch -c data/schwab-YYYYMMDD`。
- **永不 push 到 public**：`gh repo view --json isPrivate` 校验失败即停。
- **永不 push --force**：尤其不允许对 main / mainline 强推。
- **数据保鲜度**：当 `health_check()` 返回 `token_state != "valid"`
  或 `token_expires_in_days < 0.5`，停下要求用户先 reauthorize，再继续。
- **请求量预算**：单次 playbook 调用 ≤ 30 个 tool call，超过先告诉用户
  分批；这避免 Schwab 限流或 token-bucket 撑爆。

## Idempotency

各 playbook 重复运行的语义不一样，agent 需按下表判定是否要 skip：

| Playbook | 幂等性 | 重复运行行为 | 推荐 skip 条件 |
| -------- | ------ | ------------ | -------------- |
| `voo-qqq-tracker-update` | **30 分钟内幂等**（数据保鲜度限制） | 每次 commit 一条 snapshot 到 `docs/voo-qqq-tracker.md`；30 分钟内多次 commit 会污染 history | `git -C ${target_repo} log -1 --format=%ct -- docs/voo-qqq-tracker.md` 距 now < 1800 秒 → skip 并告诉用户 |
| `summary-md-refresh` | **30 分钟内幂等** | 每次重写 `## Latest snapshot` 段；30 分钟内重复 commit 会污染 history | `git -C ${target_repo} log -1 --format=%ct -- docs/summary.md` 距 now < 1800 秒 → skip 并告诉用户 |
| `watchlist-snapshot` | **不幂等（设计）** | 每次会**覆盖** `docs/watchlist.md` 的 Latest snapshot 段，并 **覆盖** `docs/watchlist-history/<date>.md`（同一天再跑就被覆盖） | 一般 1 个月跑 1 次；同一天若需重跑 → 告诉用户当日历史快照会被覆盖，征得同意后继续 |
| `option-chain-research` | **完全可重复** | 每次生成 **新的** `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md`（按当天日期命名）；同一天同一 symbol 重跑会覆盖当日 snapshot，但不会污染往日记录 | 同一天同一 symbol 重跑 → 询问用户是否要覆盖当日 snapshot；不同 symbol 或不同日期 → 直接跑 |

agent 在每个 playbook 启动 pre-flight 之后立即判定，skip 时**不调用任何 Schwab tool**（保护配额），只告诉用户为什么 skip。

## Reference

- `playbooks/voo-qqq-tracker-update.md`
- `playbooks/watchlist-snapshot.md`
- `playbooks/summary-md-refresh.md`
- `playbooks/option-chain-research.md`
