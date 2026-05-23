---
name: Bug report
about: A skill playbook misbehaves, frontmatter is rejected, or markdown renders wrong.
title: "bug: <short summary>"
labels: ["bug"]
---

## Category

- [ ] **Playbook failure** — a `workflows` playbook's steps no longer
      produce the expected markdown output.
- [ ] **SKILL frontmatter not honored** — the agent ignored
      `language_directive`, `auto_activate`, `compatible_mcp_version`,
      or another frontmatter field.
- [ ] **Markdown rendering issue** — a page renders incorrectly on
      GitHub / inside the agent's UI (broken table, escaped backticks,
      wrong heading nesting).
- [ ] **Stale link / reference** — a `references/*.md` page links to a
      file that no longer exists or has moved.
- [ ] **Other** — describe below.

## Affected skill

- [ ] `schwab-marketdata-ops` (zh-CN primary)
- [ ] `schwab-marketdata-ops-en` (English mirror)
- [ ] `schwab-marketdata-workflows` (zh-CN primary)
- [ ] `schwab-marketdata-workflows-en` (English mirror)

## Environment

| Field | Value |
| ----- | ----- |
| Agent host (Cursor / Claude Code / etc.) | host name + version |
| Skill repo commit | `git rev-parse HEAD` |
| Companion `schwab-marketdata-mcp` version | `get_server_info().server_version` |
| Renderer (if rendering issue) | GitHub web / agent UI / VS Code preview |

## What you did

Quote the user prompt that activated the skill, plus the file path of
the playbook / reference that misbehaved.

```text
<paste user prompt here>
```

## Expected behavior

What the SKILL.md / reference says should happen.

## Actual behavior

What actually happened — a screenshot, the agent transcript, or a
quoted markdown excerpt.

## Additional context

- Did this start after a specific commit?
- Does it reproduce in the other language mirror (CN ↔ EN)?
