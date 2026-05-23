# schwab-marketdata-skill

[English](./README.md) | [简体中文](./README_zh.md)

![License](https://img.shields.io/github/license/kevinkda/schwab-marketdata-skill)
![Translation](https://img.shields.io/badge/i18n-EN%20%2B%20zh--CN-blue)
![Skills](https://img.shields.io/badge/skills-2-blue)
![Release](https://img.shields.io/github/v/release/kevinkda/schwab-marketdata-skill)
![Releases](https://img.shields.io/github/release-date/kevinkda/schwab-marketdata-skill?label=last%20release)

> **v0.3 sprint (in flight)** — Sprint A Deliverable 2 rewrites the
> `summary-md-refresh` playbook to v2 (DuckDB-cache-aware, scoped to a
> single weekly snapshot section that does not overwrite hand-written
> narrative).  See:
>
> - [`schwab-marketdata-workflows/playbooks/summary-md-refresh.md`](./schwab-marketdata-workflows/playbooks/summary-md-refresh.md) (zh)
> - [`schwab-marketdata-workflows-en/playbooks/summary-md-refresh.md`](./schwab-marketdata-workflows-en/playbooks/summary-md-refresh.md) (en)
> - [`schwab-marketdata-workflows/playbooks/shakeout-analysis-v2.md`](./schwab-marketdata-workflows/playbooks/shakeout-analysis-v2.md)
>   (zh) — Shakeout v2 with DuckDB cache + 8-signal scan.

Two complementary Cursor / Claude **Skills** that wrap the
[`schwab-marketdata-mcp`](../schwab-marketdata-mcp) server. Both skills are
**read-only documentation packages**; the actual tool calls are made by the
MCP server.

---

## Overview

This repository ships two skills, each in two parallel language variants
(Chinese primary + English mirror), so an agent can be steered to whichever
prose language fits the user's request:

- **`schwab-marketdata-ops`** — single-tool reference. Use it for "give me a
  quote", "fetch this option chain", or "explain this 401 / 429".
- **`schwab-marketdata-workflows`** — multi-step playbooks. Use it for
  "refresh `summary.md`", "update `voo-qqq-tracker.md`", or "regenerate
  `watchlist.md`".

Both skills:

- Share the same MCP server (`schwab-marketdata-mcp`).
- Share the same activation handshake (`get_server_info` → `health_check`).
- Share the same governance rules (private-repo-only writes; no Trader API
  calls; no token leakage in logs).
- Differ only in prose language and the `language_directive` frontmatter
  field.

---

## Skill variants

| Skill | Language | When to use |
| ----- | -------- | ----------- |
| [`schwab-marketdata-ops`](schwab-marketdata-ops/SKILL.md) | 简体中文 (primary) | Single tool calls, OAuth / 401 / 429 troubleshooting, exact tool schema lookup. |
| [`schwab-marketdata-ops-en`](schwab-marketdata-ops-en/SKILL.md) | English (mirror) | Same scope as `schwab-marketdata-ops`, English prose. |
| [`schwab-marketdata-workflows`](schwab-marketdata-workflows/SKILL.md) | 简体中文 (primary) | Multi-step playbooks that update markdown in `kevinkda/stock-personal` (private). |
| [`schwab-marketdata-workflows-en`](schwab-marketdata-workflows-en/SKILL.md) | English (mirror) | Same scope as `schwab-marketdata-workflows`, English prose. |

> Use **ops** for "I just need a quote / option chain / a debug answer."
> Use **workflows** for "refresh `summary.md` / `voo-qqq-tracker.md` /
> `watchlist.md`."

---

## Translation coverage

The English mirror is a structural translation of the Chinese primary —
all reference files are now fully translated.

| Category | Total files | Fully translated | Placeholders |
| -------- | ----------- | ---------------- | ------------ |
| `SKILL.md` (top-level)         | 2  | 2  | 0  |
| Quick Start                    | 7  | 7  | 0  |
| Tools reference                | 8  | 8  | 0  |
| Concepts                       | 4  | 4  | 0  |
| Workflow playbooks             | 4  | 4  | 0  |
| OAuth                          | 6  | 6  | 0  |
| Integration                    | 4  | 4  | 0  |
| Operations                     | 3  | 3  | 0  |
| Troubleshooting                | 19 | 19 | 0  |
| Top-level (other)              | 8  | 8  | 0  |
| **Total**                      | **65** | **65 (100%)** | **0** |

Each English file mirrors the Chinese source structurally (heading
graph, code blocks, tables) and links back to the Chinese version
under `Source` for cross-reference.

---

## Installation

The exact mechanism depends on your client version. Typical layouts:

### Cursor

Cursor discovers user-level skills by scanning `~/.cursor/skills/` and any
directory the user adds via Settings → Skills. Symlink (or copy) the
folders you want — pick the Chinese primary, the English mirror, or both
(Cursor accepts them as distinct skills because the directory names
differ):

```bash
# Chinese primary (default for this repo)
ln -s "$(pwd)/schwab-marketdata-ops"          ~/.cursor/skills/schwab-marketdata-ops
ln -s "$(pwd)/schwab-marketdata-workflows"    ~/.cursor/skills/schwab-marketdata-workflows

# English mirror (optional; install in addition or instead)
ln -s "$(pwd)/schwab-marketdata-ops-en"       ~/.cursor/skills/schwab-marketdata-ops-en
ln -s "$(pwd)/schwab-marketdata-workflows-en" ~/.cursor/skills/schwab-marketdata-workflows-en
```

### Claude Code

Claude Code picks up `~/.claude/skills/<name>/SKILL.md`. The same symlink
approach works:

```bash
ln -s "$(pwd)/schwab-marketdata-ops"          ~/.claude/skills/schwab-marketdata-ops
ln -s "$(pwd)/schwab-marketdata-workflows"    ~/.claude/skills/schwab-marketdata-workflows
```

### Other clients

For Kiro CLI, Cline, Roo Code, and other skills-compatible agents, see
the [Compatibility matrix](#compatibility-matrix) below.

> **Prerequisite**: the companion MCP server must already be registered.
> See [`schwab-marketdata-mcp/docs/REGISTER.md`](../schwab-marketdata-mcp/docs/REGISTER.md).

---

## Compatibility with the MCP server

| This skill repo | Compatible MCP server |
| --------------- | --------------------- |
| v0.1.x          | `schwab-marketdata-mcp >=0.1, <0.2` |

The `compatible_mcp_version` range is encoded in each skill's `SKILL.md`
frontmatter. The skill body **must** call `get_server_info` first and refuse
to continue if the running server's `server_version` does not satisfy the
range.

---

## Compatibility matrix

Verified support for skill frontmatter fields across agent clients:
**5 clients × 8 fields**.

> **Key contract**: every non-standard frontmatter field is **documentation
> only** — actual enforcement happens in `SKILL.md` body via runtime checks
> (`get_server_info` version handshake, `cwd` validation, response-language
> directive, activation handshake). Even if a client does not parse the
> frontmatter field itself, the skill behaves correctly.

Legend: ✅ full support / ⚠️ partial or implementation-defined / ❌ not supported

| Client | Tested version | `compatible_mcp_version` | `required_workspace` | `language_directive` | `auto_activate` | `activation_handshake` | `compatibility` | `dependencies` | `governance` |
| ------ | -------------- | ------------------------ | -------------------- | -------------------- | --------------- | ---------------------- | --------------- | -------------- | ------------ |
| **Cursor IDE** | ≥ 0.45 | ✅ explicit body check | ✅ agent pre-flight `cwd` check | ✅ injected as system prompt | ⚠️ field ignored, body behavior unchanged | ✅ body explicitly calls 2 tools | ✅ documented | ⚠️ documented + body checks via `get_server_info` | ✅ documented |
| **Claude Code** | ≥ 1.0 | ✅ same as above | ✅ same | ✅ same | ⚠️ same | ✅ same | ✅ same | ⚠️ same | ✅ same |
| **Kiro CLI** | ≥ 0.1 | ✅ explicit body check | ⚠️ host-dependent | ✅ same | ⚠️ same | ✅ same | ✅ documented | ⚠️ same | ✅ documented |
| **Cline** | ≥ 3.x | ✅ explicit body check (via MCP handshake) | ⚠️ partial | ✅ same | ⚠️ same | ✅ same | ✅ documented | ⚠️ same | ✅ documented |
| **Roo Code** | latest | ✅ explicit body check | ⚠️ partial | ✅ same | ⚠️ same | ✅ same | ✅ documented | ⚠️ same | ✅ documented |
| Other skills-compatible agents | — | ⚠️ implementation-defined | ⚠️ same | ⚠️ same | ⚠️ same | ⚠️ same | ⚠️ same | ⚠️ same | ⚠️ same |

### Field semantics

| Field | Meaning |
| ----- | ------- |
| `compatible_mcp_version` | Semver-like range constraining the server version this skill supports (e.g. `>=0.1,<0.2`). Validated at activation by calling `get_server_info`. |
| `required_workspace` | Only set on `schwab-marketdata-workflows`; constrains the `cwd` subtree where data may be written (`/opt/workspace/code/kevinkda/stock-personal`). |
| `language_directive` | Forces the agent to respond in a specific language. This project mandates Simplified Chinese for the primary skills. |
| `auto_activate` | Whether the agent activates the skill automatically. Always `false` here — the agent must activate based on user intent. |
| `activation_handshake` | The mandatory tool call sequence on activation (`get_server_info` → `health_check`). |
| `compatibility` | Free-form string listing clients the skill has been verified against. |
| `dependencies` | Declares MCP server / external runtime dependencies (`uv`, `python>=3.10`, etc.). |
| `governance` | Declares data classification, write constraints, and Git Safety Protocol (e.g. no force-push to `main`). |

### Recommended registration paths

| Client      | Recommended path |
| ----------- | ---------------- |
| Cursor      | `~/.cursor/skills/<name>` symlink |
| Claude Code | `~/.claude/skills/<name>` symlink |
| Kiro CLI    | `~/.kiro/skills/<name>` (version-dependent) |
| Cline       | Registered via MCP protocol (IDE settings) |
| Roo Code    | Registered via MCP protocol (IDE settings) |

---

## Authoring conventions

- **Chinese primary skills respond in 简体中文** — see the
  `language_directive` field in each `SKILL.md` frontmatter. The
  `*-en` mirrors respond in English.
- Tool inputs use the schwab-py **enum names** (e.g. `"VOLUME"`, `"NASDAQ"`),
  not the wire values (`"$DJI"`, `"day"`). The MCP server performs the
  translation.
- Every workflow playbook **must** verify
  `gh repo view kevinkda/stock-personal --json isPrivate` before writing.
  Schwab Market Data is non-redistributable; private repos are a
  contractual requirement.

---

## Companion project

- [`schwab-marketdata-mcp`](../schwab-marketdata-mcp) — the MCP server these
  skills wrap. Owns OAuth, rate limiting, retries, token rotation, and the
  12-tool surface.

---

## Acknowledgements

This skill pack is the documentation companion to
[`schwab-marketdata-mcp`](../schwab-marketdata-mcp), which is built on
top of:

- **[schwab-py](https://github.com/alexgolec/schwab-py)** by Alex Golec —
  Unofficial Charles Schwab Trader / Market Data API wrapper for Python
  (MIT License). The companion MCP server delegates all OAuth and Schwab
  HTTP traffic to `schwab-py`.
- **[mcp](https://github.com/modelcontextprotocol/python-sdk)** —
  Anthropic's official Python SDK for the Model Context Protocol
  (MIT License).

The skill markdown design pattern is inspired by Anthropic's published
skill packs (e.g. `helis-authorization`) and other skill packs in the
Cursor / Claude ecosystem.

This project is **not affiliated with, endorsed by, or sponsored by
Charles Schwab Corporation or Alex Golec**. Use at your own risk per
Schwab's [Terms of Service](https://www.schwab.com/legal/terms).

---

## License

MIT License — see [LICENSE](./LICENSE).
