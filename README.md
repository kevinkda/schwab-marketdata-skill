# schwab-marketdata-skill

Two complementary Cursor / Claude **Skills** that wrap the
[`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp)
server.  Both skills are **read-only documentation packages**; the actual
tool calls are made by the MCP server.

## Languages / 语言

This repository ships each skill in two parallel language variants. They
share the same MCP server, the same activation handshake, and the same
behavior — only the prose language and frontmatter `language_directive`
differ.

| Skill (Chinese, primary) | Skill (English mirror) | When to use |
| ------------------------ | ---------------------- | ----------- |
| `schwab-marketdata-ops` | [`schwab-marketdata-ops-en`](schwab-marketdata-ops-en/SKILL.md) | Single tool calls, OAuth / 401 / 429 troubleshooting, exact tool schema lookup. |
| `schwab-marketdata-workflows` | [`schwab-marketdata-workflows-en`](schwab-marketdata-workflows-en/SKILL.md) | Multi-step playbooks that update markdown in `kevinkda/stock-personal` (private). |

> **English mirror coverage**: the two `SKILL.md` files, all 7 Quick
> Start steps, all 8 Tools references, all 4 Concepts files, and all 4
> Workflow playbooks are **fully translated**. The remaining files
> (OAuth × 6, Integration × 4, Operations × 3, Troubleshooting × 17,
> top-level × 5 = 35 files) are **structural placeholders** — each one
> carries the H1 title, an English abstract, and a link back to the
> Chinese source for full content. Contributions to upgrade any
> placeholder to a complete translation are welcome.

| Skill                           | When to use                                                                          |
| ------------------------------- | ------------------------------------------------------------------------------------ |
| `schwab-marketdata-ops`         | Single tool calls, OAuth / 401 / 429 troubleshooting, exact tool schema lookup.      |
| `schwab-marketdata-workflows`   | Multi-step playbooks that update markdown in `kevinkda/stock-personal` (private).    |

> Use **ops** for "I just need a quote / option chain / a debug answer."
> Use **workflows** for "refresh `summary.md` / `voo-qqq-tracker.md` /
> `watchlist.md`."

---

## Compatibility with the MCP server

| This skill repo | Compatible MCP server |
| --------------- | --------------------- |
| v0.1.x          | `schwab-marketdata-mcp >=0.1, <0.2` |

The `compatible_mcp_version` range is encoded in each skill's
`SKILL.md` frontmatter.  The skill body **must** call `get_server_info`
first and refuse to continue if the running server's `server_version`
does not satisfy the range.

---

## Adding the skills to Cursor / Claude

The exact mechanism depends on your client version.  Typical layouts:

1. **Cursor** discovers user-level skills by scanning `~/.cursor/skills/`
   and any directory the user adds via Settings → Skills.  Symlink (or
   copy) the folders you want — pick the Chinese primary, the English
   mirror, or both (Cursor accepts them as distinct skills because the
   directory names differ):

   ```bash
   # Chinese primary (default for this repo)
   ln -s "$(pwd)/schwab-marketdata-ops"          ~/.cursor/skills/schwab-marketdata-ops
   ln -s "$(pwd)/schwab-marketdata-workflows"    ~/.cursor/skills/schwab-marketdata-workflows

   # English mirror (optional; install in addition or instead)
   ln -s "$(pwd)/schwab-marketdata-ops-en"       ~/.cursor/skills/schwab-marketdata-ops-en
   ln -s "$(pwd)/schwab-marketdata-workflows-en" ~/.cursor/skills/schwab-marketdata-workflows-en
   ```

2. **Claude Code** picks up `~/.claude/skills/<name>/SKILL.md`.  The same
   symlink approach works.

3. The accompanying MCP server must already be registered (see the
   server repo's README — `~/.cursor/mcp.json`).

---

## Compatibility matrix

不同 agent 客户端对 skill frontmatter 字段的支持情况。下表是经过验证
的兼容情况：**5 客户端 × 8 字段**。

> **关键约定**：所有非标准 frontmatter 字段**只是文档化约束**——真正
> 的执行靠 `SKILL.md` body 的运行时检查（`get_server_info` 版本握手 +
> `cwd` 校验 + 中文回复指令 + activation handshake）。即便客户端不识别
> frontmatter 字段本身，skill 行为仍正确。

图例：✅ 完整支持 / ⚠️ 部分支持或视实现而定 / ❌ 不支持

| 客户端 | 已测版本 | `compatible_mcp_version` | `required_workspace` | `language_directive` | `auto_activate` | `activation_handshake` | `compatibility` | `dependencies` | `governance` |
| ------ | -------- | ------------------------ | -------------------- | -------------------- | --------------- | ---------------------- | --------------- | -------------- | ------------ |
| **Cursor IDE** | ≥ 0.45 | ✅ body 显式校验 | ✅ agent pre-flight 检查 cwd | ✅ 作为 system prompt 注入 | ⚠️ 字段被忽略，body 行为不变 | ✅ body 显式调用 2 个 tool | ✅ 文档化 | ⚠️ 文档化 + body 用 `get_server_info` 校验 | ✅ 文档化 |
| **Claude Code** | ≥ 1.0 | ✅ 同上 | ✅ 同上 | ✅ 同上 | ⚠️ 同上 | ✅ 同上 | ✅ 同上 | ⚠️ 同上 | ✅ 同上 |
| **Kiro CLI** | ≥ 0.1 | ✅ body 显式校验 | ⚠️ 视 host 决定 | ✅ 同上 | ⚠️ 同上 | ✅ 同上 | ✅ 文档化 | ⚠️ 同上 | ✅ 文档化 |
| **Cline** | ≥ 3.x | ✅ body 显式校验（通过 MCP 协议握手） | ⚠️ 部分支持 | ✅ 同上 | ⚠️ 同上 | ✅ 同上 | ✅ 文档化 | ⚠️ 同上 | ✅ 文档化 |
| **Roo Code** | latest | ✅ body 显式校验 | ⚠️ 部分支持 | ✅ 同上 | ⚠️ 同上 | ✅ 同上 | ✅ 文档化 | ⚠️ 同上 | ✅ 文档化 |
| 其他 skills-compatible agents | — | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 |

### 字段语义速查

| 字段 | 说明 |
| ---- | ---- |
| `compatible_mcp_version` | semver-like 范围，约束 skill 适配的 server 版本（`>=0.1,<0.2`）；激活时 agent 调 `get_server_info` 校验 |
| `required_workspace` | 仅 `schwab-marketdata-workflows` 有；约束写入数据所在的 cwd 子树（`/opt/workspace/code/kevinkda/stock-personal`） |
| `language_directive` | 强制 agent 用某种语言回复（本项目要求 Simplified Chinese） |
| `auto_activate` | 是否自动激活；本 skill 设为 `false`（agent 应根据用户意图按需激活） |
| `activation_handshake` | 描述激活时必经的 tool 调用顺序（`get_server_info -> health_check`） |
| `compatibility` | 列出 skill 已验证兼容的客户端（自由格式字符串） |
| `dependencies` | 声明 skill 依赖的 MCP server / 外部 runtime（`uv` / `python>=3.10` 等） |
| `governance` | 声明数据分类、写入约束、Git Safety Protocol（如禁止 force-push 主分支） |

### 注册路径

| 客户端 | 推荐注册路径 |
| ------ | ------------ |
| Cursor | `~/.cursor/skills/<name>` 软链 |
| Claude Code | `~/.claude/skills/<name>` 软链 |
| Kiro CLI | `~/.kiro/skills/<name>`（视版本而定） |
| Cline | 通过 MCP 协议向 IDE 注册（IDE 设置内） |
| Roo Code | 通过 MCP 协议（IDE 设置内） |

## Authoring conventions

- **Both skills respond in 简体中文** — see the `language_directive`
  field in each `SKILL.md` frontmatter.
- Tool inputs use the schwab-py **enum names** (e.g. `"VOLUME"`,
  `"NASDAQ"`), not the wire values (`"$DJI"`, `"day"`).  The MCP server
  performs the translation.
- Every workflow playbook **must** verify
  `gh repo view kevinkda/stock-personal --json isPrivate` before writing.
  Schwab Market Data is non-redistributable; private repos are a
  contractual requirement.

## License

MIT License — see [LICENSE](./LICENSE).
