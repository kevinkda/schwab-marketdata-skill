# Contributing to schwab-marketdata-skill

Thanks for considering a contribution! This is a personal-scale **skill
pack** (a pure-markdown documentation repo) for the companion
[`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp)
server.

## Before you start

1. Read the top-level [`README.md`](README.md) and pick which of the
   four skill variants your contribution lives in:
   `schwab-marketdata-ops` (zh-CN, primary), `schwab-marketdata-ops-en`
   (English mirror), `schwab-marketdata-workflows` (zh-CN, primary),
   `schwab-marketdata-workflows-en` (English mirror).
2. Skim the matching `SKILL.md` and a few of its `references/*.md`
   pages to match the existing tone, table layout, and "→ pointer"
   style.
3. Check open issues / discussions to avoid duplicate work.

## Quality gate (must pass before PR)

- `npx markdownlint-cli2 "**/*.md"` — must exit 0. The repo ships
  `.markdownlint-cli2.jsonc`; do not loosen rules without prior
  discussion.
- `pre-commit run --all-files` — all hooks pass (gitleaks +
  detect-secrets + markdownlint).
- Local manual scan for inclusive-language violations (see below).

## CN ↔ EN mirror parity

The English `*-en` directories are structural mirrors of their Chinese
primaries. **Every** edit to a Chinese source must land with one of:

- A matching edit to the English mirror (preferred).
- A placeholder English page (H1 + 1-paragraph abstract + link back to
  the Chinese source) plus a checkbox in
  [`docs/RELEASE.md`](docs/RELEASE.md) tracking the upgrade.

Do not let the two trees drift silently — `README.md`'s "Translation
coverage" table is the source of truth for what is fully translated vs.
placeholder.

## Commit message style

Follow [Conventional Commits](https://www.conventionalcommits.org/).
Examples:

- `docs(ops): add OSI option-symbol decoding examples`
- `docs(workflows): mirror VOO/QQQ tracker playbook into -en`
- `chore(lint): replace inclusive-language violations`
- `chore(release): bump compatible_mcp_version to >=0.2,<0.3`

Subject ≤ 72 chars. Use English. Body explains *why*, not *what*.

## Branching

- `main` is the integration branch. PRs target `main`.
- For multi-PR features (e.g. translating a whole `troubleshooting/`
  family), use a topic branch.
- **Never force-push `main`** — the companion MCP repo's
  `credentials-rotate-runbook.md` documents the rationale.

## What contributions are welcome

- Upgrading any English-mirror **placeholder** page to a complete
  translation (see the table in `README.md`).
- New `references/*.md` pages that cover a previously undocumented
  edge case, error code, or workflow.
- New playbooks for the `workflows` skill — but only if they write to
  a private repo (Schwab Market Data is non-redistributable; see plan
  §1).
- Documentation polish, broken-link fixes, table-formatting nits.
- Skill activation / governance changes — please open a discussion
  first.

## Inclusive language

This project follows
[Amazon's inclusive language guidelines](https://aws.amazon.com/blogs/aws/blogpost-inclusive-language/).
Replace `master` / `blacklist` / `whitelist` etc. with `main` /
`deny list` / `allow list`. The pre-commit hook does not auto-enforce
this — please self-audit before submitting.

## Questions?

Open a [discussion](https://github.com/kevinkda/schwab-marketdata-skill/discussions) —
issues are for bugs.

## License

By submitting a PR, you agree your contribution will be licensed under
MIT (see [LICENSE](LICENSE)).
