# Playbook — `summary.md` weekly refresh (v2)

| Field             | Value                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                                    |
| target_files      | `portfolio/summary.md` (replaces only the `## 📈 Weekly snapshot (auto-generated)` section; everything else untouched) |
| schwab tools used | `get_market_hours`, `get_quotes`, `get_movers`, `get_price_history`, `get_cache_stats`           |
| max tool calls    | ≤ 8 (3-5 real API calls after cache hits)                                                        |
| version           | v2 (v0.3 sprint, Sprint A Deliverable 2.1)                                                       |
| supersedes        | v1 (≤ v0.2.x) — v1 assumed `docs/summary.md` and overwrote `## Latest snapshot`                  |

> **This playbook only runs inside the `stock-personal` repo.** If `cwd` is
> outside that subtree, switch to **read-only mode**: emit the analysis to
> chat context and **do not write** to any other repo.
>
> **v2 key changes** (vs. v1):
>
> 1. Path moved from `docs/summary.md` to `portfolio/summary.md` (matches
>    the user's actual repo layout today).
> 2. Auto-generated section heading is now `## 📈 Weekly snapshot (auto-generated)`,
>    explicitly labeled "(auto-generated)" so manual edits are never mixed in.
> 3. Added VOO / QQQ weekly trend + 7-day candle stats (computed from
>    DuckDB-cached `price_history`).
> 4. Performance: every `get_price_history` call defaults to the cache layer
>    (introduced in v0.2), so a weekly refresh costs ≤ 1 quota slot.
> 5. Forces the cache `hit_rate` field into the frontmatter so it is
>    auditable — see §10 acceptance criterion #9.

## Purpose

Once a week (typically after Friday US close, or before Monday open),
refresh a **weekly snapshot** so the user can scan last week's market in
30 seconds plus see the status of the core ETFs that map to current
holdings.  All hand-written sections — analysis, strategy retrospective,
TQQQ tracker links, discipline reminders — sit elsewhere in `summary.md`,
**never touched by this playbook**.

## Pre-flight (mandatory)

```text
1. get_server_info()                              # version handshake
2. health_check()                                 # token_state must be "valid"
3. get_cache_stats()                              # record opening hit_rate / cache_size_mb
4. git -C ${target_repo} config --get remote.origin.url
   → must end with kevinkda/stock-personal(.git)?
5. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   → must be true (else ASK the user; never auto-write)
6. cwd ∈ ${target_repo} subtree? if not → read-only mode (chat output only)
7. ls ${target_repo}/portfolio/summary.md
   → must exist; if missing → STOP (v2 does not bootstrap a fresh summary.md)
8. grep -c '^## 📈 Weekly snapshot (auto-generated)' ${target_repo}/portfolio/summary.md
   → 0 = v2 has never run; this run will append the new section
   → 1 = v2 section exists; this run will replace it whole
   → ≥ 2 = STOP, file structure is corrupt
```

## Steps

### Step 1 — Fetch market hours

```text
get_market_hours(markets_list=["EQUITY", "OPTION"])
```

Record `equity.session_state` (`open` / `closed` / `pre_market` /
`after_hours`) and the next trading day. If `closed` and today is a
weekend, use the previous trading day's close as "last week".

### Step 2 — Pull core ETF candles (DuckDB cache first)

For each `["VOO", "QQQ", "SPY", "IWM"]`:

```text
get_price_history(
    symbol=...,
    period_type="MONTH",
    period="ONE_MONTH",
    frequency_type="DAILY",
)
```

> **Cache semantics**:
>
> - Historical candles (older than 1 hour) are cached forever — no quota.
> - Candles within the last hour are force-refreshed if older than 60 s.
> - Weekly refreshes typically run after close, so most recent-hour
>   candles also come from cache (expected `hit_rate` ≥ 70%).

To bypass the cache (e.g. when suspecting data drift): set
`SCHWAB_CACHE_BYPASS=1` for one run, then unset.

### Step 3 — Pull live quotes

```text
get_quotes(symbols=["VOO", "QQQ", "SPY", "IWM", "VIX"], fields=["QUOTE", "REGULAR"])
```

`VIX` powers the risk gauge; the rest fill the "weekly close" column.

### Step 4 — Pull movers (single call to save quota)

```text
get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_UP")
```

Top 5 only.  v2 drops the losers / volume rankings — weekly reports care
about trend, not single-day spikes; the saved quota goes to the four
`price_history` calls in Step 2.

### Step 5 — Local computation

Fully local (no Schwab calls):

- Weekly Δ% (last 5 trading days)
- Weekly high / low
- Weekly average volume
- Price vs 20-day MA (using the 20+ day candle window from Step 2)
- 7-day cumulative return

### Step 6 — Final `get_cache_stats()` snapshot

Record the closing `hit_rate_24h` and `cache_size_mb`; embed both in the
frontmatter so §10 acceptance criterion #9 has a verifiable value.

## Output structure (replaces only the `## 📈 Weekly snapshot (auto-generated)` section)

```markdown
## 📈 Weekly snapshot (auto-generated)

<!-- Generated by schwab-marketdata-skill summary-md-refresh playbook v2. -->
<!-- This section is replaced whole on every run; do not edit by hand. -->
<!-- Hand-written analysis, retrospectives, discipline reminders go OUTSIDE this section (above or below). -->

> **Generated at (UTC)**: <ISO 8601 timestamp>
> **Market state**: <open|closed|pre_market|after_hours>
> **Cache hit rate (24h)**: <hit_rate>, cache size: <size> MB
> **Data source**: Schwab Market Data API (SOSA — non-redistributable)
> **MCP version**: <get_server_info().version>

### Core ETF weekly snapshot

| Ticker | Weekly close | Week Δ% | Weekly high | Weekly low | vs 20D MA | Avg weekly volume |
| ------ | ------------ | ------- | ----------- | ---------- | --------- | ----------------- |
| VOO    | …            | …       | …           | …          | …         | …                 |
| QQQ    | …            | …       | …           | …          | …         | …                 |
| SPY    | …            | …       | …           | …          | …         | …                 |
| IWM    | …            | …       | …           | …          | …         | …                 |

### Risk gauge

| Indicator | Value | Interpretation (mechanical rule; not investment advice) |
| --------- | ----- | ------------------------------------------------------- |
| VIX       | …     | < 15 low / 15-25 neutral / ≥ 25 elevated                |

### Top 5 weekly NASDAQ gainers

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

---
```

Write rules:

1. If §Pre-flight #8 grep returned 0 → **append** the section to the file
   (preceded by one blank line).
2. If it returned 1 → **replace** the section whole, from
   `## 📈 Weekly snapshot (auto-generated)` up to (but not including)
   the next `^##` heading (or end of file).
3. **Do not** modify any byte outside that section, including trailing
   newline / line-ending whitespace.

## Write & commit

```bash
cd ${target_repo}

# Use a data branch to avoid polluting main.
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/summary-weekly-$(date +%Y%m%d)
fi

# Step 6 has already written portfolio/summary.md
# (only the ## 📈 Weekly snapshot (auto-generated) section is changed).
git add portfolio/summary.md
git commit -m "data(schwab): summary weekly snapshot $(date -u +%Y-%m-%dT%H:%MZ)"

# Do NOT force-push.  A normal push to the data branch is enough; review via PR.
```

## Acceptance criteria

After completion, verify each item (run the command, confirm output, then tick):

- [ ] **commit created**: `git -C ${target_repo} log -1 --format="%H %s"`
      prints the latest commit hash + a message starting with
      `data(schwab): summary weekly snapshot`.
- [ ] **only portfolio/summary.md modified**:
      every path from `git -C ${target_repo} diff --stat HEAD~1` is
      `portfolio/summary.md`, nothing else.
- [ ] **diff sits inside the §Weekly snapshot section only**:
      `git -C ${target_repo} show HEAD --unified=0 -- portfolio/summary.md | grep '^@@'`
      all hunk start lines fall between `## 📈 Weekly snapshot (auto-generated)`
      and the next `^##` heading.
- [ ] **health_check still valid**: `uv run python -m schwab_marketdata_mcp.health`
      exit code = 0.
- [ ] **§Weekly snapshot section contains all 4 tables (or fewer, if data missing)**:
      `awk '/^## 📈 Weekly snapshot/,/^---$/' portfolio/summary.md | grep -c '^|'` ≥ 12
      (4 tables × 3 header rows = 12 — lower bound).
- [ ] **frontmatter includes cache hit_rate field**:
      `awk '/^## 📈 Weekly snapshot/,/^---$/' portfolio/summary.md | grep -c 'Cache hit rate'` ≥ 1.
- [ ] **gitleaks pass**: `pre-commit run gitleaks --files portfolio/summary.md`
      exit code = 0.
- [ ] **hand-written sections untouched**: pick one paragraph from outside
      the §Weekly snapshot section (e.g. §1 account profile) and confirm
      `grep -F` still finds its full text in the new file.
- [ ] **cache hit rate ≥ 50%**: the closing `get_cache_stats()` `hit_rate_24h`
      is ≥ 0.5 (proof the cache really reduced Schwab calls).

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # undo commit, keep working-tree changes
# Inspect the working tree, then choose git restore / git stash
git restore portfolio/summary.md
# Never force-push main (Git Safety Protocol).
```

## Failure modes

| Symptom                                                    | Action                                                                                                           |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `portfolio/summary.md` does not exist                       | **STOP**. Report "v2 does not bootstrap"; ask the user to create the initial version manually.                   |
| `## 📈 Weekly snapshot (auto-generated)` appears ≥ 2 times | **STOP**, file is corrupt; ask the user to merge/clean before re-running.                                        |
| `SchwabAuthError(reason="refresh_token_expired")`          | Stop; ask the user to run `auth login_flow`.                                                                     |
| `SchwabRateLimitError`                                     | Wait `retry_after_seconds`, retry once; if it fails again → STOP.                                                |
| `gh repo view` fails / repo is not private                 | **STOP and refuse to write**. Tell the user; do not bypass.                                                      |
| `get_cache_stats()` reports `enabled == false`             | Continue, but write "cache disabled" into the frontmatter so the user knows to re-enable.                        |
| VIX data unavailable                                       | Risk-gauge row says `N/A`; do **not** fabricate a VIX value.                                                     |
| One ETF unreachable (e.g. IWM temporarily halted)          | That row's metrics all `N/A`; append a "data missing: &lt;symbol&gt; @ &lt;utc&gt;" footer line.                |
| Existing §Weekly snapshot section + diff bleeds elsewhere  | **STOP**, dump the diff into chat; ask the user to review before re-running.                                     |
| DuckDB lock conflict (another process is using `cache.duckdb`) | Wait 5 s and retry once; if still locked → set `SCHWAB_CACHE_BYPASS=1` for one run and note "cache miss" in the frontmatter. |

## Relationship to other playbooks

- `voo-qqq-tracker-update.md` (daily; finer VOO/QQQ section) — different
  cadence; the weekly snapshot does **not** replace the daily.
- `shakeout-analysis-v2.md` (on demand; 8-signal scan + decision matrix)
  — different trigger; the weekly snapshot is a recurring task.
- `watchlist-refresh.md` (off-portfolio symbols) — different data set;
  the weekly snapshot only covers the four core ETFs.

The v2 weekly snapshot is the **lowest-cost** recurring task, designed to
let the user "glance once a week and feel grounded".  It does not replace
any finer-grained playbook.
