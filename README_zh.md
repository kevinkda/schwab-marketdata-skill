# schwab-marketdata-skill

[English](./README.md) | [简体中文](./README_zh.md)

[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)
[![Companion](https://img.shields.io/badge/companion-schwab--marketdata--mcp-blue.svg)](../schwab-marketdata-mcp)

两个相互配套的 Cursor / Claude **Skill**，封装
[`schwab-marketdata-mcp`](../schwab-marketdata-mcp) 服务。两个 skill 都是
**只读文档包**；真正的工具调用由 MCP 服务端完成。

---

## 项目概述

本仓库提供两个 skill，每个都同时存在中英两个并行版本（中文为主版本 +
英文镜像），便于 agent 根据用户语言偏好选用：

- **`schwab-marketdata-ops`** —— 单工具参考。适合「给我报个价」、
  「拉一下这个 option chain」、「解释一下这个 401 / 429」之类的请求。
- **`schwab-marketdata-workflows`** —— 多步 playbook。适合「刷新
  `summary.md`」、「更新 `voo-qqq-tracker.md`」、「重新生成
  `watchlist.md`」之类的请求。

两个 skill：

- 共享同一个 MCP 服务端（`schwab-marketdata-mcp`）。
- 共享同一套激活握手（`get_server_info` → `health_check`）。
- 共享同一套 governance 规则（仅写入私有仓库；不调用 Trader API；日志
  不泄露 token）。
- 仅在文案语言与 frontmatter 中的 `language_directive` 字段上有差异。

---

## Skill 变体

| Skill | 语言 | 适用场景 |
| ----- | ---- | -------- |
| [`schwab-marketdata-ops`](schwab-marketdata-ops/SKILL.md) | 简体中文（主版本） | 单工具调用、OAuth / 401 / 429 排查、tool schema 精确查找。 |
| [`schwab-marketdata-ops-en`](schwab-marketdata-ops-en/SKILL.md) | English（镜像） | 与 `schwab-marketdata-ops` 范围一致，英文文案。 |
| [`schwab-marketdata-workflows`](schwab-marketdata-workflows/SKILL.md) | 简体中文（主版本） | 多步 playbook，写入 `kevinkda/stock-personal`（私有仓库）。 |
| [`schwab-marketdata-workflows-en`](schwab-marketdata-workflows-en/SKILL.md) | English（镜像） | 与 `schwab-marketdata-workflows` 范围一致，英文文案。 |

> 「单纯要个 quote / option chain / 调试结论」用 **ops**。
> 「刷新 `summary.md` / `voo-qqq-tracker.md` / `watchlist.md`」用
> **workflows**。

---

## 翻译覆盖度

英文镜像是中文主版本的结构化翻译——部分文件已完整翻译，其余文件保留为
占位（含标题与回链中文源文件）。

| 类别 | 总文件数 | 已完整翻译 | 占位 |
| ---- | -------- | ---------- | ---- |
| `SKILL.md`（顶层） | 2  | 2  | 0  |
| Quick Start         | 7  | 7  | 0  |
| Tools 参考          | 8  | 8  | 0  |
| Concepts            | 4  | 4  | 0  |
| Workflow playbooks  | 4  | 4  | 0  |
| OAuth               | 6  | 0  | 6  |
| Integration         | 4  | 0  | 4  |
| Operations          | 3  | 0  | 3  |
| Troubleshooting     | 17 | 0  | 17 |
| 顶层（其他）         | 5  | 0  | 5  |
| **合计**            | **60** | **25** | **35** |

占位文件包含 H1 标题、一段英文摘要，以及指回中文源文件的链接。欢迎贡献，
把任意占位文件升级为完整翻译——可参考已存在的 `*-en` 文件作为风格参考。

---

## 安装

具体方式取决于你的客户端版本，常见布局如下。

### Cursor

Cursor 会扫描 `~/.cursor/skills/` 以及在「Settings → Skills」里手动添加
的目录来发现用户级 skill。把你想用的目录软链（或拷贝）过去——可以选中文
主版本、英文镜像，或两者都装（目录名不同，Cursor 会当作不同 skill 处
理）：

```bash
# 中文主版本（本仓库默认）
ln -s "$(pwd)/schwab-marketdata-ops"          ~/.cursor/skills/schwab-marketdata-ops
ln -s "$(pwd)/schwab-marketdata-workflows"    ~/.cursor/skills/schwab-marketdata-workflows

# 英文镜像（可选；可与中文主版本同时安装）
ln -s "$(pwd)/schwab-marketdata-ops-en"       ~/.cursor/skills/schwab-marketdata-ops-en
ln -s "$(pwd)/schwab-marketdata-workflows-en" ~/.cursor/skills/schwab-marketdata-workflows-en
```

### Claude Code

Claude Code 扫描 `~/.claude/skills/<name>/SKILL.md`，软链方式相同：

```bash
ln -s "$(pwd)/schwab-marketdata-ops"          ~/.claude/skills/schwab-marketdata-ops
ln -s "$(pwd)/schwab-marketdata-workflows"    ~/.claude/skills/schwab-marketdata-workflows
```

### 其他客户端

Kiro CLI、Cline、Roo Code 等其他兼容 skill 的 agent 见下文
[兼容性矩阵](#兼容性矩阵)。

> **前置条件**：配套的 MCP 服务必须先注册好。参见
> [`schwab-marketdata-mcp/docs/REGISTER.md`](../schwab-marketdata-mcp/docs/REGISTER.md)。

---

## 与 MCP 服务端的版本兼容

| 本 skill 仓库版本 | 兼容的 MCP server 版本 |
| ----------------- | ---------------------- |
| v0.1.x            | `schwab-marketdata-mcp >=0.1, <0.2` |

`compatible_mcp_version` 范围在每个 skill 的 `SKILL.md` frontmatter 中
声明。skill body **必须**先调用 `get_server_info`，若运行中的 server
`server_version` 不在该范围内，则拒绝继续执行。

---

## 兼容性矩阵

不同 agent 客户端对 skill frontmatter 字段的支持情况。下表是经过验证的
兼容情况：**5 客户端 × 8 字段**。

> **关键约定**：所有非标准 frontmatter 字段**只是文档化约束**——真正的
> 执行靠 `SKILL.md` body 的运行时检查（`get_server_info` 版本握手 +
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
| 其他 skill 兼容 agent | — | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 | ⚠️ 视实现而定 |

### 字段语义速查

| 字段 | 说明 |
| ---- | ---- |
| `compatible_mcp_version` | semver-like 范围，约束 skill 适配的 server 版本（`>=0.1,<0.2`）；激活时 agent 调 `get_server_info` 校验。 |
| `required_workspace` | 仅 `schwab-marketdata-workflows` 有；约束写入数据所在的 cwd 子树（`/opt/workspace/code/kevinkda/stock-personal`）。 |
| `language_directive` | 强制 agent 用某种语言回复（本项目中文主版本要求 Simplified Chinese，英文镜像要求 English）。 |
| `auto_activate` | 是否自动激活；本 skill 设为 `false`（agent 应根据用户意图按需激活）。 |
| `activation_handshake` | 描述激活时必经的 tool 调用顺序（`get_server_info` → `health_check`）。 |
| `compatibility` | 列出 skill 已验证兼容的客户端（自由格式字符串）。 |
| `dependencies` | 声明 skill 依赖的 MCP server / 外部 runtime（`uv` / `python>=3.10` 等）。 |
| `governance` | 声明数据分类、写入约束、Git Safety Protocol（如禁止 force-push 主分支）。 |

### 推荐注册路径

| 客户端 | 推荐注册路径 |
| ------ | ------------ |
| Cursor      | `~/.cursor/skills/<name>` 软链 |
| Claude Code | `~/.claude/skills/<name>` 软链 |
| Kiro CLI    | `~/.kiro/skills/<name>`（视版本而定） |
| Cline       | 通过 MCP 协议向 IDE 注册（IDE 设置内） |
| Roo Code    | 通过 MCP 协议（IDE 设置内） |

---

## 编写约定

- **中文主版本 skill 用 简体中文 回复** —— 见每个 `SKILL.md` frontmatter
  里的 `language_directive` 字段。`*-en` 镜像则用英文回复。
- 工具入参使用 schwab-py 的 **enum 名称**（如 `"VOLUME"`、`"NASDAQ"`），
  而不是 wire value（如 `"$DJI"`、`"day"`）。MCP 服务端会做转换。
- 每个 workflow playbook **必须**在写入前先校验
  `gh repo view kevinkda/stock-personal --json isPrivate`。Schwab Market
  Data 不可二次分发，写入私有仓库是合同义务。

---

## 相关项目

- [`schwab-marketdata-mcp`](../schwab-marketdata-mcp) —— 本 skill 包装的
  MCP 服务端，负责 OAuth、限流、重试、token 轮换以及 12 个 tool 的接口。

---

## License

MIT License —— 详见 [LICENSE](./LICENSE)。
