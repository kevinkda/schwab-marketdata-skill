#!/usr/bin/env bash
#
# validate-structure.sh — structural contract check for this skill repo.
#
# A skill repo ships pure Markdown (no Python), so the "100% coverage" gate
# used by the MCP repos does not apply. Instead we lint content with
# markdownlint-cli2 (see .github/workflows/markdownlint.yml) and assert the
# structural invariants below. This script is the structure half of that gate;
# it is fast, has zero network dependency, and runs in CI as a separate job.
#
# Checks:
#   1. Every SKILL.md has valid YAML front matter with the required keys
#      (name + description). The version-range key is repo-specific.
#   2. Each skill has a Simplified-Chinese source dir and an "-en" English
#      mirror dir, and every Markdown file present in one exists in the other.
#   3. Every playbook contains the required sections: Pre-flight, Steps,
#      Acceptance criteria, Rollback. A failure-handling section
#      (Failure modes / Cautions) is required as a soft check (warning).
#   4. front-matter MCP dependency version ranges are syntactically valid
#      (semver-ish range expressions such as ">=0.3,<0.4").
#
# Exit non-zero on any hard failure; warnings do not fail the build.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[0;33m'
NC=$'\033[0m'

errors=0
warnings=0

fail() { echo "${RED}FAIL${NC} $*"; errors=$((errors + 1)); }
warn() { echo "${YLW}WARN${NC} $*"; warnings=$((warnings + 1)); }
pass() { echo "${GRN}OK${NC}   $*"; }

# ---------------------------------------------------------------------------
# Discover skill source directories: any top-level dir holding a SKILL.md,
# excluding the English mirrors (handled as pairs) and tooling dirs.
# ---------------------------------------------------------------------------
mapfile -t skill_md_files < <(find . -maxdepth 2 -name SKILL.md \
  -not -path './.git/*' -not -path './build/*' | sort)

if [ "${#skill_md_files[@]}" -eq 0 ]; then
  fail "no SKILL.md files found under repo root"
  echo ""
  echo "Summary: ${errors} error(s), ${warnings} warning(s)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: extract the YAML front-matter block (between the first two '---').
# ---------------------------------------------------------------------------
extract_frontmatter() {
  awk 'NR==1 && $0 != "---" { exit 1 }
       NR==1 { next }
       $0 == "---" { exit 0 }
       { print }' "$1"
}

# ---------------------------------------------------------------------------
# Check 1 + 4: SKILL.md front matter
# ---------------------------------------------------------------------------
echo "== Check 1/4: SKILL.md front matter =="
for skill in "${skill_md_files[@]}"; do
  if ! fm="$(extract_frontmatter "$skill")"; then
    fail "$skill: missing YAML front matter (must start with '---')"
    continue
  fi

  # Required keys present (top-level, allowing block scalars).
  for key in name description; do
    if ! printf '%s\n' "$fm" | grep -qE "^${key}:"; then
      fail "$skill: front matter missing required key '${key}'"
    fi
  done

  # name must be a non-empty single token matching the dir name convention.
  name_val="$(printf '%s\n' "$fm" | sed -nE 's/^name:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p' | head -1)"
  if [ -z "$name_val" ]; then
    fail "$skill: 'name' is empty"
  else
    dir_name="$(basename "$(dirname "$skill")")"
    # The English mirror dir is "<name>-en"; both should resolve to name_val.
    expected="${dir_name%-en}"
    if [ "$name_val" != "$expected" ]; then
      warn "$skill: name '${name_val}' != dir '${expected}'"
    fi
  fi

  # Check 4: any version-range expressions must be syntactically valid.
  # Matches compatible_mcp_version, version_range, and dependency ranges.
  while IFS= read -r range; do
    [ -z "$range" ] && continue
    # Accept semver-ish ranges: optional op + version, comma-separated.
    if ! printf '%s' "$range" | grep -qE '^(>=|<=|>|<|=|~|\^)?[0-9]+(\.[0-9]+){0,2}([[:space:]]*,[[:space:]]*(>=|<=|>|<|=|~|\^)?[0-9]+(\.[0-9]+){0,2})*$'; then
      fail "$skill: invalid version range expression: '${range}'"
    fi
  done < <(printf '%s\n' "$fm" \
    | grep -E '^[[:space:]]*(compatible_mcp_version|version_range):' \
    | sed -E 's/^[^:]*:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')

  pass "$skill front matter"
done

# ---------------------------------------------------------------------------
# Check 2: bilingual mirror parity (zh source dir <-> <dir>-en mirror)
# ---------------------------------------------------------------------------
echo ""
echo "== Check 2/4: bilingual mirror parity =="
for skill in "${skill_md_files[@]}"; do
  dir="$(dirname "$skill")"
  base="${dir%-en}"
  # Only drive the parity check from the source (non -en) dir.
  [ "$dir" != "$base" ] && continue

  mirror="${base}-en"
  if [ ! -d "$mirror" ]; then
    fail "$base: missing English mirror dir '${mirror}'"
    continue
  fi

  # Compare the set of relative .md paths in each tree.
  src_files="$(cd "$base" && find . -name '*.md' | sort)"
  mir_files="$(cd "$mirror" && find . -name '*.md' | sort)"
  if [ "$src_files" != "$mir_files" ]; then
    fail "$base <-> $mirror: Markdown file set differs:"
    diff <(printf '%s\n' "$src_files") <(printf '%s\n' "$mir_files") \
      | sed 's/^/      /' || true
  else
    pass "$base <-> $mirror parity ($(printf '%s\n' "$src_files" | grep -c .) files)"
  fi
done

# ---------------------------------------------------------------------------
# Check 3: required playbook sections
# ---------------------------------------------------------------------------
echo ""
echo "== Check 3/4: playbook required sections =="
mapfile -t playbooks < <(find . -path '*/playbooks/*.md' -not -path './.git/*' | sort)

if [ "${#playbooks[@]}" -eq 0 ]; then
  echo "     (no playbooks in this repo — skipping)"
else
  required=("Pre-flight" "Steps" "Acceptance criteria" "Rollback")
  for pb in "${playbooks[@]}"; do
    missing=()
    for sec in "${required[@]}"; do
      # Heading match is case-insensitive and tolerates trailing qualifiers
      # like "(mandatory)" / "（强制）".
      if ! grep -qiE "^#{1,3}[[:space:]]+${sec}" "$pb"; then
        missing+=("$sec")
      fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
      fail "$pb: missing required section(s): ${missing[*]}"
    else
      pass "$pb sections"
    fi
    # Soft check: a failure-handling section (Failure modes OR Cautions).
    if ! grep -qiE '^#{1,3}[[:space:]]+(Failure modes|Cautions)' "$pb"; then
      warn "$pb: no 'Failure modes' / 'Cautions' section"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Summary: ${errors} error(s), ${warnings} warning(s)"
[ "$errors" -eq 0 ] || exit 1
