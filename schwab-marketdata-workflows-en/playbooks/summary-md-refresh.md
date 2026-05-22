# Playbook — `summary.md` refresh

| Field             | Value                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                  |
| target_files      | `docs/summary.md`                                                              |
| schwab tools used | `get_quote`, `get_quotes`, `get_movers`, `get_market_hours`                    |
| max tool calls    | ≤ 10                                                                            |

## Purpose

Produce a one-page "what happened today" summary for the user's
personal-investing repo.  It is intended to be **scannable in 30
seconds**, not exhaustive — so the playbook deliberately limits the
number of tool calls.

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Steps

1. `get_market_hours(markets_list=["EQUITY", "OPTION"])` — record session.
2. `get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_UP")` — top
   gainers.
3. `get_movers(index="NASDAQ", sort_order="PERCENT_CHANGE_DOWN")` — top
   losers.
4. `get_movers(index="NYSE", sort_order="VOLUME")` — high-volume names.
5. `get_quotes(symbols=["VOO", "QQQ", "SPY", "IWM"], fields=["QUOTE", "REGULAR"])` — market headline tickers.

## Output structure (`docs/summary.md`)

Replace the `## Latest snapshot` section (preserve any other narrative
sections the user has hand-written above / below):

```markdown
## Latest snapshot

_Updated <UTC timestamp>; market session: <open|closed|pre-|after->_

### Market headlines

| Ticker | Price | Day Δ | Day Δ% |
| ------ | ----- | ----- | ------ |
| VOO    | …     | …     | …      |
| QQQ    | …     | …     | …      |
| SPY    | …     | …     | …      |
| IWM    | …     | …     | …      |

### Top gainers (NASDAQ)

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

### Top losers (NASDAQ)

| Symbol | Last | Δ% | Vol |
| ------ | ---- | -- | --- |
| …      | …    | …  | …   |

### High volume (NYSE)

| Symbol | Last | Vol |
| ------ | ---- | --- |
| …      | …    | …   |
```

## Write & commit

```bash
cd ${target_repo}
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/summary-$(date +%Y%m%d)
fi
git add docs/summary.md
git commit -m "data(schwab): summary refresh $(date -u +%Y-%m-%dT%H:%MZ)"
```

## Acceptance criteria

After completion, verify each item:

- [ ] **commit created**: `git -C ${target_repo} log -1 --format="%H %s"`
      prints the latest commit hash + a message with the `data(schwab):` prefix
- [ ] **only files under docs/ modified**:
      every path from `git -C ${target_repo} diff --stat HEAD~1` starts with `docs/`
      (should be exactly `docs/summary.md`)
- [ ] **health_check still valid**:
      `uv run python -m schwab_marketdata_mcp.health` exits 0 and prints `token_state == "valid"`
- [ ] **gitleaks pass**:
      `pre-commit run gitleaks --files docs/summary.md` exits 0
- [ ] **file head spot-check**: `head -50 ${target_repo}/docs/summary.md`
      shows a new `## Latest snapshot` section with
      timestamp / market session / a VOO|QQQ|SPY|IWM table;
      user-authored narrative sections were not overwritten

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # undo the commit but keep working-tree changes
# Inspect what changed, then decide between git restore / git stash
# Never force-push main (see credentials-rotate-runbook.md Git Safety Protocol §13-25)
```

## Tone

The narrative section above the snapshot table is **user-authored** and
must NOT be overwritten by this playbook.  Treat anything outside the
`## Latest snapshot` heading as untouchable.
