# Quick Start — Step 2: Configure `.env` & local credentials

> **目标**：把 Step 1 拿到的 App Key / App Secret / Callback URL 写入
> `schwab-marketdata-mcp` 仓库根目录的 `.env`，并验证 pre-commit 钩子
> 能拦住任何对 `.env` 的 commit。

## 前置条件

- [ ] 已完成 [Step 1](step-1-developer-portal-app.md)，拿到 App Key / Secret
- [ ] 已 `git clone https://github.com/kevinkda/schwab-marketdata-mcp` 到
      本机（或 fork 后 clone 自己的）
- [ ] 已安装 `uv`（<https://docs.astral.sh/uv/getting-started/installation/>）

## 操作步骤

```bash
cd /path/to/schwab-marketdata-mcp

# 1) 用模板复制（永远不要直接编辑 .env.example 后改名）
cp .env.example .env
chmod 600 .env

# 2) 编辑 .env 三个非可选字段
$EDITOR .env

# 3) 同步安装项目依赖（含 schwab-py、mcp、httpx 等）
uv sync

# 4) 安装 pre-commit 钩子（gitleaks + detect-secrets，防 .env 被误 commit）
uv run pre-commit install
```

`.env` 里**至少**需要三行（其余字段保持注释状态即可）：

```bash
SCHWAB_APP_KEY=<32 字符 App Key>
SCHWAB_APP_SECRET=<16 字符 App Secret>
SCHWAB_CALLBACK_URL=https://127.0.0.1:8182
```

`SCHWAB_CALLBACK_URL` 必须与 Step 1 在 Developer Portal 注册的 Callback
URL **字节级相同**（差一个 `/`、端口、协议 都算不一致）。

## 期望产出

- `.env` 文件已创建，权限 = `600`
- `.env` 三个字段已填好真值（`dummy-not-a-real-secret` 已替换）
- `pre-commit` 钩子已安装到 `.git/hooks/pre-commit`
- `uv sync` 退出码 = 0，`.venv/` 已生成

## 验证清单

- [ ] `stat -c '%a %n' .env`（macOS：`stat -f '%A %N' .env`）= `600 .env`
- [ ] `grep -c 'dummy-not-a-real-secret' .env` = `0`（占位串已全部替换）
- [ ] `uv run pre-commit run --all-files` exit 0（钩子全过）
- [ ] **故意尝试 commit `.env`**（仅作演练）：
      ```bash
      git add -f .env  # -f 因为 .gitignore 已拦
      git commit -m "test"  # 应被 gitleaks 阻止
      git restore --staged .env  # 撤销
      ```
      预期：`gitleaks` 立即 fail，commit 被拒。
- [ ] `python -m schwab_marketdata_mcp.auth login_flow --dry-run`（不打开
      浏览器）输出包含 `Callback URL: https://127.0.0.1:8182`，且与 Portal
      上的注册值一致。

## 常见错误

| 现象 | 处置 |
| ---- | ---- |
| `.env` 权限是 `644` 或 `664` | `chmod 600 .env`，server 启动时也会强制要求 |
| 把 `.env` 放到了 git 跟踪范围 | `git rm --cached .env` 后立即去 [Step 1](step-1-developer-portal-app.md) **rotate App Secret**，再走 [`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md) |
| `pre-commit install` 找不到 `pre-commit` | 先 `uv sync` 把 dev deps 装好；或 `pip install pre-commit` |
| `.env` 里 `SCHWAB_CALLBACK_URL` 末尾多了 `/` | 改成与 Portal 完全一致；OAuth 在 callback 阶段会因为 CSRF 校验失败 |
| `uv sync` 报 `python>=3.10` not found | 装一个支持 3.10+ 的 Python（推荐 3.11 或 3.12） |

## 不要做的事

- **不要** 把 `.env` 拷到 iCloud / Dropbox / OneDrive 同步目录。
- **不要** 把 App Secret 粘到聊天工具、issue tracker、PR 描述里。
- **不要** 在公共仓库（即使是 fork 的私 fork）跑 `git push origin main`
  之前手动确认 `git status` 看不到 `.env`。

## 下一步

→ [Step 3: First OAuth flow](step-3-first-oauth.md)

## 参考

- `.env.example` 完整模板：见 MCP 仓库 `/.env.example`
- pre-commit 配置：见 MCP 仓库 `.pre-commit-config.yaml`
- 凭证泄露应急 runbook：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
