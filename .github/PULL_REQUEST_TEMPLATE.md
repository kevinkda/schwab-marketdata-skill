# Pull request

## Summary

<!-- 1–3 sentences describing what changed and why. Link the issue
this closes. -->

## Type of change

- [ ] New / updated playbook (`workflows`)
- [ ] New / updated reference page (`ops`)
- [ ] CN ↔ EN mirror parity (translation upgrade or placeholder fill)
- [ ] Documentation polish only
- [ ] Tooling / CI / lint config

## Affected skill

- [ ] `schwab-marketdata-ops` (zh-CN primary)
- [ ] `schwab-marketdata-ops-en` (English mirror)
- [ ] `schwab-marketdata-workflows` (zh-CN primary)
- [ ] `schwab-marketdata-workflows-en` (English mirror)

## Checklist

- [ ] `npx markdownlint-cli2 "**/*.md"` exits 0.
- [ ] `pre-commit run --all-files` passes.
- [ ] Conventional commit message — `docs(...)`, `chore(...)`,
      `feat(...)`, etc.
- [ ] CN ↔ EN mirror updated together (or placeholder + tracked
      follow-up).
- [ ] [`CHANGELOG.md`](../CHANGELOG.md) updated under
      `## [Unreleased]` (if user-visible).
- [ ] `compatible_mcp_version` in `SKILL.md` checked — bumped only
      when the companion MCP server release requires it.
- [ ] Inclusive-language audit — no `master` / `blacklist` /
      `whitelist` / `kill` / `abort`. Use `main` / `deny list` /
      `allow list` / `stop` instead.
- [ ] No secrets, `.env`, `token.json`, or Bearer tokens committed.
- [ ] `references/*.md` links resolved (no 404s).

## Test plan

<!-- How did you verify this change? -->

- [ ] Rendered the changed markdown on GitHub web / locally.
- [ ] If a playbook was changed, dry-ran it in a non-production
      directory (no real Schwab calls required).

## Screenshots (if applicable)

<!-- Optional — preferred for rendering / table fixes. -->
