# Release Process — schwab-marketdata-skill

This document describes the end-to-end release process for the
`schwab-marketdata-skill` repository, which ships **Skill packages** consumed
by Cursor, Claude Code, Kiro CLI, Cline, Roo Code, and other
skills-compatible agents.

A "release" of this repo is a tagged, immutable snapshot that pairs with a
matching version of [`schwab-marketdata-mcp`](https://github.com/kevinkda/schwab-marketdata-mcp).

> **Scope:** GitHub repository releases (tags + GitHub Releases UI).
> Skills are consumed directly from the GitHub tag URL by the agent runtime;
> there is no separate package registry.

---

## 1. Prerequisites

Before cutting a release, confirm **all** of the following:

| Item | Verification command |
|------|----------------------|
| `gh` CLI installed (>= 2.50) | `gh --version` |
| `gh` authenticated to `github.com` | `gh auth status` |
| Working tree clean on `main` | `git status` shows nothing to commit |
| Local `main` is up-to-date with `origin/main` | `git fetch && git status -sb` |
| `markdownlint-cli2` exits 0 | `markdownlint-cli2 "**/*.md"` |
| All `SKILL.md` files have valid YAML frontmatter | manual check (see §2.2) |
| EN mirrors are in sync with their CN counterparts | manual diff per skill |
| The matching `schwab-marketdata-mcp` version exists on GitHub | `gh release view vX.Y.Z --repo kevinkda/schwab-marketdata-mcp` |

If any of these fail, **stop** and fix before proceeding.

> **First-time auth on a new machine** (interactive — do **not** run from an
> agent without user consent):
> ```bash
> gh auth login --hostname github.com --git-protocol https --web
> ```

---

## 2. Versioning Policy (SemVer)

The repository follows [Semantic Versioning 2.0.0](https://semver.org/) at
the **repository level** (single tag covers all skills inside).

### 2.1 When to bump

| Change type | Bump | Example |
|------|------|---------|
| Doc-only edit, typo, language polish, EN mirror catch-up | **patch** | `0.1.0 → 0.1.1` |
| New skill added, new section in an existing skill, new playbook | **minor** | `0.1.0 → 0.2.0` |
| Removed skill, renamed skill folder, breaking handshake change | **major** | `0.1.0 → 1.0.0` |
| Pre-1.0 breaking change | **minor** (allowed under SemVer 0.x) | `0.1.0 → 0.2.0` |

### 2.2 Compatibility with the MCP server

Each `SKILL.md` declares an MCP-version constraint in its frontmatter:

```yaml
compatible_mcp_version: ">=0.1,<0.2"
```

When releasing the skill repo, **verify** that this constraint still matches
the MCP server's current version. If you publish a skill release that
requires a newer MCP, bump that constraint **before** tagging.

> **Frontmatter `version:` field:** the current `SKILL.md` files do **not**
> carry a per-skill `version:` field. The repository tag is the source of
> truth. If you later add a per-skill `version:`, document it here and bump
> in lockstep with the repo tag.

**Current version:** `0.1.0` (initial public release line). **No tag pushed
yet.**

**Tag format:** `vX.Y.Z` (e.g. `v0.1.0`). Always prefixed with `v`.

---

## 3. Release Checklist

The full sequence to release **`v0.1.0`** (substitute the actual version):

### 3.1 Pre-flight

```bash
# 1. Confirm clean state
cd /opt/workspace/code/kevinkda/schwab-marketdata-skill
git checkout main
git pull --ff-only origin main
git status                                 # must be clean

# 2. Lint all markdown
markdownlint-cli2 "**/*.md"                # must exit 0

# 3. Spot-check a couple of SKILL.md frontmatters
head -20 schwab-marketdata-ops/SKILL.md
head -20 schwab-marketdata-workflows/SKILL.md
```

### 3.2 Bump version markers

If/when a per-skill `version:` field is introduced, update it in **every**
`SKILL.md` (CN + EN mirrors) so they stay in lockstep:

```yaml
---
name: schwab-marketdata-ops
version: 0.1.0                  # ← bump here (when field is added)
compatible_mcp_version: ">=0.1,<0.2"
...
---
```

For the current 0.1.0 release with no per-skill `version:` field, this step
is a no-op — the tag itself is the version marker.

### 3.3 Update CHANGELOG.md

If `CHANGELOG.md` does not yet exist, create it from the template in
[Section 5](#5-changelogmd-template).

Add a new entry **at the top** of `CHANGELOG.md`:

```markdown
## [0.1.0] — 2026-MM-DD

### Added
- Initial public release of skill packages: `schwab-marketdata-ops`,
  `schwab-marketdata-workflows`, plus EN mirrors.

### Compatibility
- Requires `schwab-marketdata-mcp` ≥ 0.1, < 0.2.
```

### 3.4 Commit + tag

```bash
git add CHANGELOG.md
# Plus any version-marker edits if applicable
git commit -m "chore(release): v0.1.0"
git tag -a v0.1.0 -m "Release v0.1.0"
```

### 3.5 Push

```bash
git push origin main
git push origin v0.1.0
```

### 3.6 Create the GitHub Release

Extract the `[0.1.0]` section of `CHANGELOG.md` into a temporary file
`/tmp/release-notes-skill-v0.1.0.md`, then:

```bash
gh release create v0.1.0 \
  --title "v0.1.0 — Initial public release" \
  --notes-file /tmp/release-notes-skill-v0.1.0.md \
  --verify-tag
```

> Add `--draft` if you want to review the page before publishing, or
> `--prerelease` for non-stable lines (e.g. `v0.2.0-rc.1`).

### 3.7 Verify

```bash
gh release view v0.1.0 --web              # opens in browser
gh release list                           # confirms it appears
```

Manually confirm on GitHub:
- Tag `v0.1.0` is present.
- Release notes render correctly.
- Source tarballs (`.tar.gz`, `.zip`) are auto-attached by GitHub.
- The tarball, when extracted, contains all four skill folders
  (`schwab-marketdata-ops`, `schwab-marketdata-ops-en`,
  `schwab-marketdata-workflows`, `schwab-marketdata-workflows-en`).

---

## 4. Release Notes Template

Save as the `--notes-file` argument to `gh release create`.

```markdown
## What's Changed

### Added
- <user-visible new skills, playbooks, or sections, in past tense>

### Changed
- <wording / structural changes>

### Fixed
- <typo, broken link, lint fixes>

### Compatibility
- Requires `schwab-marketdata-mcp` `>=X.Y,<X.(Y+1)`.

### Deprecated
- <skills or sections scheduled for removal>

### Removed
- <removed skills or sections>

## Migration

<For minor/major releases: explicit before/after snippets if a skill name,
folder, or handshake changed. Omit for pure-patch releases.>

## Acknowledgements

Thanks to <contributor handles> for issues, reviews, and language polish.

## Full Changelog

https://github.com/kevinkda/schwab-marketdata-skill/compare/<prev-tag>...v0.1.0
```

---

## 5. CHANGELOG.md Template

If `CHANGELOG.md` does not yet exist at the repo root, create it with this
content. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
### Changed
### Fixed
### Compatibility

## [0.1.0] — 2026-MM-DD

### Added
- Initial public release.
- Skill: `schwab-marketdata-ops` — single-call playbooks and OAuth/error
  troubleshooting for the 12 MCP tools.
- Skill: `schwab-marketdata-workflows` — multi-tool playbooks that refresh
  `summary.md`, `voo-qqq-tracker.md`, `watchlist.md`, and shakeout snapshots.
- English mirrors: `schwab-marketdata-ops-en`, `schwab-marketdata-workflows-en`.
- Bilingual top-level README (English + 简体中文).
- `markdownlint-cli2` config with MD060 disabled for CJK compatibility.

### Compatibility
- Requires `schwab-marketdata-mcp` `>=0.1, <0.2`.

[Unreleased]: https://github.com/kevinkda/schwab-marketdata-skill/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kevinkda/schwab-marketdata-skill/releases/tag/v0.1.0
```

---

## 6. Rollback / Recovery

If a release was published in error (wrong notes, wrong commit, broken
markdown, missing skill files):

```bash
# Delete the GitHub Release (keeps the tag by default)
gh release delete v0.1.0 --yes

# Delete the tag locally and on the remote
git tag -d v0.1.0
git push --delete origin v0.1.0
```

After rollback, fix the underlying issue, **bump the patch version**
(`v0.1.0 → v0.1.1`), and run the full release checklist again. Never re-use
a tag name that has been published, even if deleted.

---

## 7. Current Readiness Assessment (as of doc creation)

| Item | Status |
|------|--------|
| `markdownlint-cli2` exits 0 | ✅ |
| EN mirrors complete (25 sections) + 40 placeholders | ✅ |
| LICENSE present (MIT) | ✅ |
| README (EN + ZH, with i18n nav) | ✅ |
| `main` pushed to `origin` | ✅ (in sync with `origin/main`) |
| `CHANGELOG.md` | ⚠️ **missing — create before tagging** |
| Per-skill `version:` field in `SKILL.md` | ⚠️ Not present. Repo tag is the version of record. |
| Uncommitted edits in working tree | ⚠️ A couple of `M` files at doc creation time — review and commit/discard before release |
| Companion MCP release tag | ⚠️ Not yet released. The skill release should reference the corresponding `schwab-marketdata-mcp` `vX.Y.Z` tag — release the MCP server **first**, then the skill repo. |

**Verdict:** ready for `v0.1.0` once `CHANGELOG.md` is added, the working
tree is clean, and the matching `schwab-marketdata-mcp` `v0.1.0` is
released.

---

## 8. Notes for Future Releases

- Keep `CHANGELOG.md` updated **as part of each PR**, not only at release
  time.
- When the MCP server bumps a minor version, update every `SKILL.md`'s
  `compatible_mcp_version` constraint in the **same** PR that bumps this
  repo's version.
- Keep CN ↔ EN mirror parity: any change to a CN skill must land with the
  matching EN edit (or a clearly tracked follow-up).
- Consider automating Steps 3.4–3.6 with a `scripts/release.sh` once the
  process has run cleanly two or three times manually.
