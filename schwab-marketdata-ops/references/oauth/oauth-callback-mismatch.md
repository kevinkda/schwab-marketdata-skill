# OAuth — Callback URL mismatch deep dive

> 列出 9 种常见的 callback URL 不一致的具体形态，与字符级修复。

`SCHWAB_CALLBACK_URL` 必须与 Developer Portal 上注册的 Callback URL
**字节级相同**（差一个字符都视为不一致）。

## 9 种常见不一致形态

| # | `.env` 中                            | Portal 注册的                         | 修复                                   |
| - | ------------------------------------ | ------------------------------------- | -------------------------------------- |
| 1 | `https://127.0.0.1:8182`             | `https://127.0.0.1:8182/`             | `.env` 末尾加 `/`                       |
| 2 | `https://127.0.0.1:8182/`            | `https://127.0.0.1:8182`              | `.env` 末尾去 `/`                       |
| 3 | `http://127.0.0.1:8182`              | `https://127.0.0.1:8182`              | 改 `http` 为 `https`（Schwab 拒 http）  |
| 4 | `https://127.0.0.1`                  | `https://127.0.0.1:8182`              | `.env` 加 `:8182`，或 Portal 去 `:8182` |
| 5 | `https://localhost:8182`             | `https://127.0.0.1:8182`              | 改 `localhost` 为 `127.0.0.1`           |
| 6 | `https://127.0.0.1:8182/callback`    | `https://127.0.0.1:8182`              | 去 `/callback` 路径                    |
| 7 | `https://127.0.0.1:8182?foo=bar`     | `https://127.0.0.1:8182`              | 去查询字符串                           |
| 8 | 大写或混合大小写 host 名             | 全小写 host                           | 全部小写                                |
| 9 | URL 末尾有不可见字符（trailing CR）  | 无                                    | `cat -A .env` 查；用 `sed -i 's/\r$//' .env` |

## `--dry-run` 提前验证

```bash
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run
# 期望输出：
#   Callback URL: https://127.0.0.1:8182
# 把这个值与 https://developer.schwab.com/dashboard/apps 上的注册值
# 字符级 diff
```

也可以用 shell：

```bash
ENV_VAL="$(grep -E '^SCHWAB_CALLBACK_URL=' .env | cut -d= -f2-)"
PORTAL_VAL='https://127.0.0.1:8182'  # 手工从 Portal 复制
diff <(printf '%s' "$ENV_VAL") <(printf '%s' "$PORTAL_VAL")
# 无输出 = 完全一致
```

## OAuth callback 阶段的具体报错

| 错误                                              | 含义                                                          |
| ------------------------------------------------- | ------------------------------------------------------------- |
| `MismatchingStateException ("CSRF Warning!")`     | schwab-py 收到的 redirect_uri ≠ 它发出去的 → 多半是 .env vs Portal 不一致 |
| `OAuth2Error: invalid_grant`                      | code 已被换过 / 超 5 分钟过期；重新跑 `auth login_flow`       |
| `OAuth2Error: invalid_client`                     | App Key 或 App Secret 错；检查 `.env` 三字段                  |
| `redirect_uri_mismatch`                           | Schwab 服务端返回；与上面 `MismatchingStateException` 同因   |

## 修复后的验证

```bash
# 1) `.env` 改完，立即 dry-run 看新值
uv run python -m schwab_marketdata_mcp.auth login_flow --dry-run

# 2) 重新跑 OAuth
uv run python -m schwab_marketdata_mcp.auth login_flow

# 3) 验证 token 真的拿到了
uv run python -m schwab_marketdata_mcp.health
```

## 不要做的事

- **不要** 试图在 Portal 用 wildcard / 多 callback URL（Schwab 不支持
  wildcard，只接受**精确字符串匹配**；多 callback 只在某些 enterprise
  app 里支持，普通个人 app 不行）。
- **不要** 在 `.env` 里把 callback URL 加引号（shell 解析后字符就不一
  样了）；schwab-py 直接读字面值。

## 参考

- 端到端 OAuth：[`oauth-overview.md`](oauth-overview.md)
- `login_flow`：[`oauth-login-flow.md`](oauth-login-flow.md)
- `manual_flow`：[`oauth-manual-flow.md`](oauth-manual-flow.md)
- 一般认证错误处置：[`../troubleshooting/auth-callback-url-mismatch.md`](../troubleshooting/auth-callback-url-mismatch.md)
