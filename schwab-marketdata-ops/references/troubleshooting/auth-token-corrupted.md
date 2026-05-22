# Troubleshooting — `SchwabAuthError(reason="token_corrupted")`

token.json 文件存在但内容无法解析或字段不完整。先备份再删除，
再走一次 OAuth。

## Symptom

- `health_check()` 返回 `token_state == "malformed"`
- server 启动时 stderr 报 `JSONDecodeError` 或缺关键字段（如
  `access_token`、`refresh_token`、`creation_timestamp`）
- 业务 call 返回 `{"error":"SchwabAuthError","reason":"token_corrupted"}`

## Root cause（4 种典型）

1. token.json 被部分写入（写到一半进程 crash、磁盘满、文件系统异常）
2. 被外部工具改坏（编辑器误编辑、sync 工具半路抢占、备份脚本截断）
3. schwab-py 版本升级后字段名 / 结构变了，旧文件不兼容
4. 跨机器 rsync 时被截断（`rsync` 默认 chunk 写，断网会留下半文件）

## 检查命令

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"

# 1) JSON 是否合法
cat "$TOKEN_PATH" | python -m json.tool
# 报错则确认 JSON 损坏

# 2) 关键字段是否齐全
python3 -c "
import json, sys
data = json.loads(open('$TOKEN_PATH').read())
required = {'creation_timestamp', 'token'}
missing = required - data.keys()
if missing:
    print('missing top-level keys:', missing)
inner_required = {'access_token', 'refresh_token'}
inner_missing = inner_required - data.get('token', {}).keys()
if inner_missing:
    print('missing token-level keys:', inner_missing)
"
```

## 修复命令

```bash
TOKEN_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/token.json"

# 1) 先备份（不要直接 rm，给自己留个返回点）
cp "$TOKEN_PATH" "${TOKEN_PATH}.bak.$(date +%s)"

# 2) 删除原文件
rm "$TOKEN_PATH"

# 3) 重新 OAuth
uv run python -m schwab_marketdata_mcp.auth login_flow
```

## 验证命令

```bash
uv run python -m schwab_marketdata_mcp.health   # exit 0
# 期望：token_state == "valid"
```

## 备份保留多久？

最多 7 天（refresh_token 寿命）。超过 7 天即使你想 rollback 也没意义
（旧 RT 已被服务端 invalidate）。建议每周清理一次：

```bash
find "${XDG_STATE_HOME:-$HOME/.local/state}/schwab-marketdata-mcp/" \
    -name 'token.json.bak.*' -mtime +7 -delete
```

## 不要做的事

- **不要** 直接 `rm` 不备份 —— 万一新 OAuth 跑不通，你想看损坏前的字段
  做诊断都没机会。
- **不要** 试图手工编辑 token.json 修复字段 —— refresh_token 是服务端
  签发的，你修不了。

## 参考

- TokenState 4 种：[`auth-token-states.md`](auth-token-states.md)
- 凭证轮换 runbook：[`../credentials-rotate-runbook.md`](../credentials-rotate-runbook.md)
- token 生命周期：[`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
