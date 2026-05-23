# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Two Cursor / Claude Code skills: `schwab-marketdata-ops` (single-tool MCP
  calls + troubleshooting) and `schwab-marketdata-workflows` (multi-step
  playbooks for VOO/QQQ tracker, watchlist, summary refresh, option-chain
  research).
- 60+ reference files split into 8 categories: quick-start (7 steps), tools
  (8 family files), oauth (5), concepts (4), integration (4 client SDKs),
  operations (3), troubleshooting (17 by reason/symptom), faq (35 Q&A).
- English mirror skills (`schwab-marketdata-ops-en` /
  `schwab-marketdata-workflows-en`): 25 fully-translated + 40 scaffolded
  placeholders.
- Bilingual READMEs (English master + Chinese mirror via README_zh.md).
- markdownlint-cli2 config for CJK-compatible linting; all 132 markdown files
  pass exit 0.
- Compatibility matrix covering 5 clients (Cursor / Claude Code / Kiro CLI /
  Cline / Roo Code) × 8 frontmatter fields.
- `chore(license)`: MIT License (Copyright 2026 Tang Keyin), aligns with
  companion mcp repository.
- `docs(readme)`: Acknowledgements section crediting schwab-py and Anthropic
  mcp SDK.

### Security

- All playbooks include `gh repo view --json isPrivate` precheck to enforce
  Schwab ToS data-redistribution constraints.
- `data(schwab):` commit message prefix convention for downstream tracking.
- Credential rotation runbook explicitly disallows force-pushing main (Git
  Safety Protocol).

[Unreleased]: https://github.com/kevinkda/schwab-marketdata-skill/compare/...HEAD
