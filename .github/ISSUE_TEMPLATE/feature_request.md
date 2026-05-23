---
name: Feature request
about: Suggest a new playbook, reference section, or language mirror.
title: "feat: <short summary>"
labels: ["enhancement"]
---

## Category

- [ ] **New playbook** for the `workflows` skill (multi-step,
      end-to-end markdown deliverable).
- [ ] **New reference section** for the `ops` skill (single-tool
      schema, troubleshooting page, OAuth corner case).
- [ ] **New language mirror** beyond the existing zh-CN + English
      pair.
- [ ] **Upgrade a placeholder English page** to a complete
      translation.
- [ ] **Other** — describe below.

## Motivation

What user problem does this solve? Quote a representative user prompt
that the existing skill content cannot answer well.

## Proposed change

- Affected files / new file paths.
- For a new playbook: list the steps the agent should perform and the
  output markdown it produces.
- For a new reference section: sketch the page outline (H2/H3
  headings) and the symptom → remediation table.
- For a new language: ISO code, target audience, frontmatter
  `language_directive` value.

## Plan / scope alignment

- [ ] Does this respect Schwab's non-redistributable Market Data
      constraint? (Any output must land in a private repo.)
- [ ] Does this stay within the read-only Market Data API surface
      (no Trader API)?
- [ ] Does this require a new MCP server tool? If yes, the
      corresponding `schwab-marketdata-mcp` issue must land first.

## Additional context

Link to relevant agent transcripts, related issues, or third-party
references (e.g. an Anthropic skill pack pattern you want to mirror).
