# Troubleshooting — `token_state` 4 状态详解

> `health_check()` 返回的 `token_state` 是 **本地文件状态枚举**，与
> `SchwabAuthError(reason=...)` 是不同维度。本文给出 4 个状态的具体
> 表现与处置。

## 状态对照表

| `token_state`      | 触发条件                                                       | 立即处置                                                          |
| ------------------ | -------------------------------------------------------------- | ----------------------------------------------------------------- |
| `valid`            | 文件存在 + JSON 合法 + 字段齐全 + 权限正确                       | ✅ 继续业务                                                        |
| `missing`          | `token.json` 不存在                                             | `auth login_flow`                                                 |
| `malformed`        | JSON 损坏 / 字段缺失 / schwab-py 字段不兼容                     | 备份 + 删 + `auth login_flow`                                     |
| `insecure_perms`   | 文件权限 ≠ `600` 或父目录 ≠ `700`                              | `chmod 600` token.json + `chmod 700` 父目录                       |

## 1. `valid`

```bash
uv run python -m schwab_marketdata_mcp.health
# {"token_state":"valid","token_age_days":0.5,"token_expires_in_days":6.5,...}
```

`token_state == "valid"` **不代表 token 一定能调通业务 API**。它只代表
本地文件结构合规。如果业务 call 还是返回 `SchwabAuthError`，多半是
refresh_token 在 7 天内被服务端 revoke 了（极罕见，通常是
**Reset App Secret** 触发的级联），需要重新走 OAuth。

## 2. `missing`

最常见出现于：

- 首次安装 server 后还没跑过 `auth login_flow`
- 你 `rm token.json` 之后还没重新 OAuth
- `--config-dir` 指向的目录不存在或没有 token.json

```bash
# 验证：
ls -la "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/"
# 应看到 token.json；若不存在则 missing

# 修复：
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 3. `malformed`

最常见出现于：

- `token.json` 被部分写入（写到一半进程被杀、磁盘满）
- 被外部工具（编辑器 / sync 工具）改坏
- schwab-py 升级后字段名变了

```bash
# 验证：
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
cat "$TOKEN_PATH" | python -m json.tool
# 报 JSONDecodeError = JSON 损坏
# 报 KeyError = 字段缺失（更可能是 schwab-py 版本问题）

# 修复：
cp "$TOKEN_PATH" "${TOKEN_PATH}.bak.$(date +%s)"
rm "$TOKEN_PATH"
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 4. `insecure_perms`

最常见出现于：

- 用 `cp -p` 把 token 从别处复制过来时丢权限
- `umask` 不是 `077` 时 schwab-py 第一次写文件就权限不对
- `rsync` 同步未加 `--perms`
- 在 macOS 上从 NTFS / FAT32 外置盘恢复

```bash
# 验证：
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"
stat -c '%a %n' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"  # Linux
stat -f '%A %N' "$TOKEN_PATH" "$(dirname "$TOKEN_PATH")"  # macOS
# 期望：600 ...token.json   700 ...schwab-marketdata-mcp

# 修复：
chmod 700 "$(dirname "$TOKEN_PATH")"
chmod 600 "$TOKEN_PATH"

# 验证修复：
uv run python -m schwab_marketdata_mcp.health   # exit 0
```

## 状态转换图

```
       initial
         │ install server
         ▼
    [missing] ──── auth login_flow ──── [valid] ──── (使用 7 天)
                                          │
                          token.json 损坏 │
                                          ▼
                                    [malformed]
                                          │
                          备份 + 删 + login_flow
                                          ▼
                                       [valid]
                                          │
                          权限被改 / 同步丢权限
                                          ▼
                                  [insecure_perms]
                                          │
                          chmod 600 / 700
                                          ▼
                                       [valid]
                                          │
                          7 天到期
                                          ▼
                              SchwabAuthError(reason="refresh_token_expired")
                              （注意：token_state 仍可能是 "valid"，因为本地
                                文件没动，但任何业务 call 都会失败）
```

注意第 4 步的微妙：**7 天到期不会改变 token_state**，因为本地文件
还是合法的；它只在你**真正调业务 API** 时才表现为
`SchwabAuthError(reason="refresh_token_expired")`。所以 health 模块还
会看 `token_expires_in_days < 12h` 来主动预警。

## 不要做的事

- **不要** 信赖 `token_state == "valid"` 等于"全部就绪"。还要看
  `token_expires_in_days` 与 `last_request_status` 才完整。
- **不要** 把 token.json 从其他机器 rsync 过来 —— rotate-on-use 与跨机
  根本不兼容。

## 参考

- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- 6 种 reason 详解：[`auth-overview.md`](auth-overview.md) 与 reason 子文件
- health 巡检自动化：[`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
