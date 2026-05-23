# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-05-23

### Added

- **`summary-md-refresh` playbook v2** (zh + en, 403 lines added,
  129 removed): rewrite leveraging schwab-marketdata-mcp v0.3.0
  health_check overall_status + cache hourly breakdown + 6-step
  workflow targeting stock-personal/summary.md weekly refresh.
- **`shakeout-analysis-v2` playbook enhancements**: AC #9 cache
  rows-changed assertion + fail-mode #10 DuckDB lock conflict
  (zh + en mirrors).
- **Dependabot config** (`.github/dependabot.yml`): weekly GitHub
  Actions dependency updates only (no Python deps in skill repo).
- **README badges + v0.3 sprint navigation** (English + Chinese
  mirrors).

### Changed

- All 4 SKILL.md frontmatters bump `compatible_mcp_version` from
  `>=0.2,<0.3` to `>=0.3,<0.4`, reflecting reliance on the v0.3.0
  health_check state machine and hourly cache breakdown for playbook
  pre-flight gates.

### Compatibility

- Requires schwab-marketdata-mcp >=0.3,<0.4 (verified against v0.3.0).
- Falling back to v0.2.x will fail Activation handshake.

## [0.2.1] - 2026-05-23

### Changed

- **English mirror reaches 100% translation coverage** (was 25/65 = 38%
  in v0.2.0 → 65/65 = 100% now). All 40 placeholder scaffolds upgraded
  to full translations across 4 reference categories:
  - 19 troubleshooting references (auth / rate-limit / validation /
    transient routing + per-symptom playbooks, 1,406 lines)
  - 6 oauth references (overview / login_flow / manual_flow /
    self-host-callback / callback-mismatch / token-lifecycle, 624 lines)
  - 4 integration references (cli-jq-pipe / python-mcp-client /
    typescript-mcp-client / rust-mcp-client, 754 lines)
  - 3 operations references (multi-machine / observability-and-caching
    / rate-limit-token-bucket, 381 lines)
  - 8 top-level references (error-recovery / faq 35 Q&A / tos-snapshot /
    credentials-rotate-runbook / rate-limits-and-paging + 3 legacy
    redirectors, 620 lines)
- README "Translation coverage" table updated from "25 complete + 40
  scaffolded" to "65 complete (100%)".
- Industry-standard terminology applied consistently:
  `credential rotation`, `Cartesian product`, `rate limit / throttling`,
  `time and sales`, `rotate-on-use`, etc. API field names, enum values,
  JSON keys, command paths, and URLs preserved verbatim. Each EN file
  retains a `## Source` link to its CN counterpart for ongoing
  cross-reference.

## [0.2.0] - 2026-05-23

### Added

- **`shakeout-analysis-v2.md` playbook** (Chinese + English mirror,
  189 / 201 lines): 6-step end-to-end workflow leveraging the
  companion mcp v0.2.0 DuckDB cache. Covers VOO/QQQ/SPY default
  scan, 8-signal local detection per voo-qqq-tracker.md §10
  methodology, and 7-section AI-generated `research/shakeout-
  YYYY-MM-DD.md` output. Includes pre-flight cache hit-rate gate
  (≥30%), acceptance criteria (8 items), rollback procedure, and
  failure-mode table (9 rows).
- workflows SKILL.md tables of playbooks now list shakeout-analysis-v2
  in both zh and en mirrors.

### Compatibility

- Requires `schwab-marketdata-mcp >=0.2,<0.3` (DuckDB cache + 14
  tools). Falls back to v0.1.1 by setting `SCHWAB_CACHE_ENABLED=false`,
  but pre-flight cache hit-rate gate will fail.

## [0.1.1] - 2026-05-23

### Added

- "Data coverage clarifications" section in `schwab-marketdata-ops/SKILL.md`
  and `schwab-marketdata-ops-en/SKILL.md` mirroring the companion MCP
  README's clarifications.
- `tool-reference-streaming.md` reference documenting the new
  `get_streaming_snapshot` tool (in both Chinese and English mirrors).
- `CONTRIBUTING.md` with skill authoring conventions and bilingual
  mirror requirements.
- `.github/ISSUE_TEMPLATE/` with bug_report / feature_request templates
  for skill-specific issues (playbook failure, frontmatter bugs,
  markdown rendering).
- `.github/PULL_REQUEST_TEMPLATE.md`.
- README license / i18n / skills / release badges.
- `docs/RELEASE.md §9 Repository metadata` with `gh repo edit`
  commands.

## [0.1.0] - 2026-05-23

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
- Bilingual READMEs (English primary + Chinese mirror via README_zh.md).
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

[Unreleased]: https://github.com/kevinkda/schwab-marketdata-skill/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.3.0
[0.2.1]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.2.1
[0.2.0]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.2.0
[0.1.1]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.1.1
[0.1.0]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.1.0
