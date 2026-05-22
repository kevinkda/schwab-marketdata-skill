# schwab-marketdata-skill

Two complementary Cursor / Claude **Skills** that wrap the
[`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp)
server.  Both skills are **read-only documentation packages**; the actual
tool calls are made by the MCP server.

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
   copy) the two folders inside this repo:

   ```bash
   ln -s "$(pwd)/schwab-marketdata-ops"       ~/.cursor/skills/schwab-marketdata-ops
   ln -s "$(pwd)/schwab-marketdata-workflows" ~/.cursor/skills/schwab-marketdata-workflows
   ```

2. **Claude Code** picks up `~/.claude/skills/<name>/SKILL.md`.  The same
   symlink approach works.

3. The accompanying MCP server must already be registered (see the
   server repo's README — `~/.cursor/mcp.json`).

---

## Compatibility matrix

不同 agent 客户端对 skill frontmatter 字段的支持不一致。下表是经过验证的兼容情况：

| 客户端 | 已测版本 | `compatible_mcp_version` | `required_workspace` | `language_directive` | 备注 |
| ------ | -------- | ------------------------ | -------------------- | -------------------- | ---- |
| **Cursor IDE** | ≥ 0.45 | 支持（在 SKILL.md body 显式调用 `get_server_info` 校验） | 支持（agent 在 pre-flight 检查 cwd） | 支持（作为 system prompt 注入） | 推荐通过 `~/.cursor/skills/` 软链方式注册 |
| **Claude Code** | ≥ 1.0 | 支持（同上，body 显式校验） | 支持（agent 在 pre-flight 检查 cwd） | 支持 | 推荐通过 `~/.claude/skills/` 软链方式注册 |
| **Kiro CLI** | ≥ 0.1 | 支持（同上） | 部分支持（取决于 host） | 支持 | 仅 skills-compatible 模式 |
| **Cline** | ≥ 3.x | 支持（同上） | 部分支持 | 支持 | 通过 MCP 协议注册 |
| 其他 skills-compatible agents | — | 视实现而定 | 视实现而定 | 视实现而定 | 凡是认 `name` + `description` frontmatter 的都可用，附加字段会被忽略但不报错 |

**关键约定**：所有非标准 frontmatter 字段（`compatible_mcp_version`, `required_workspace`, `language_directive`）**只是文档化约束**——真正的执行靠 SKILL.md body 的运行时检查（`get_server_info` 版本握手 + `cwd` 校验 + 中文回复指令）。这意味着即便客户端不识别 frontmatter 字段本身，skill 行为仍正确。

## Authoring conventions

* **Both skills respond in 简体中文** — see the `language_directive`
  field in each `SKILL.md` frontmatter.
* Tool inputs use the schwab-py **enum names** (e.g. `"VOLUME"`,
  `"NASDAQ"`), not the wire values (`"$DJI"`, `"day"`).  The MCP server
  performs the translation.
* Every workflow playbook **must** verify
  `gh repo view kevinkda/stock-personal --json isPrivate` before writing.
  Schwab Market Data is non-redistributable; private repos are a
  contractual requirement.

License: see [LICENSE](LICENSE).
