# Playbook — Watchlist snapshot

| Field             | Value                                                                |
| ----------------- | -------------------------------------------------------------------- |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                        |
| target_files      | `docs/watchlist.md` (and optionally `docs/watchlist-history/<date>.md`) |
| schwab tools used | `get_quotes`, `search_instruments`, `get_market_hour_single`         |
| max tool calls    | ≤ 12 (split if watchlist > 50 symbols)                                |

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Inputs

The playbook reads `docs/watchlist.md` and parses the symbol list from
the first markdown table (column "Symbol").  If parsing finds 0 symbols,
**stop** and ask the user where the canonical list lives — do not
autogenerate one from elsewhere.

## Steps

1. Parse the watchlist into a Python list `symbols: list[str]`
   (uppercase normalize, drop blanks).
2. If `len(symbols) > 50`, split into batches of ≤50.  For each batch:
   `get_quotes(symbols=batch, fields=["QUOTE", "FUNDAMENTAL", "REGULAR"])`.
3. `get_market_hour_single(market_id="EQUITY")` — record session.
4. For each symbol whose `lastPrice` deviates >5% from the previous
   snapshot (look up the most recent
   `docs/watchlist-history/*.md` file), call
   `search_instruments(symbols=[that_one], projection="FUNDAMENTAL")`
   to enrich with fundamentals.  **Cap this enrichment at 5 symbols
   per snapshot** to stay under the per-call budget.
5. Build a markdown table sorted by `netPercentChange` desc.
6. Write to:
   - `docs/watchlist.md` — replace the "Latest snapshot" section.
   - `docs/watchlist-history/YYYY-MM-DD.md` — full snapshot copy with
     timestamp.

## Write & commit

```bash
cd ${target_repo}
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/watchlist-$(date +%Y%m%d)
fi
git add docs/watchlist.md docs/watchlist-history/$(date -u +%Y-%m-%d).md
git commit -m "data(schwab): watchlist snapshot $(date -u +%Y-%m-%dT%H:%MZ)"
```

## Acceptance criteria

After completion, verify each item:

- [ ] **commit created**: `git -C ${target_repo} log -1 --format="%H %s"`
      prints the latest commit hash + a message with the `data(schwab):` prefix
- [ ] **only files under docs/ modified**:
      every path from `git -C ${target_repo} diff --stat HEAD~1` starts with `docs/`
      (including `docs/watchlist.md` and `docs/watchlist-history/<date>.md`)
- [ ] **health_check still valid**:
      `uv run python -m schwab_marketdata_mcp.health` exits 0 and prints `token_state == "valid"`
- [ ] **gitleaks pass**:
      `pre-commit run gitleaks --files <changed_files>` exits 0
- [ ] **file head spot-check**: `head -50 ${target_repo}/docs/watchlist.md`
      shows the new "Latest snapshot" section;
      `head -50 ${target_repo}/docs/watchlist-history/$(date -u +%Y-%m-%d).md`
      shows the full monthly snapshot

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # undo the commit but keep working-tree changes
# Inspect what changed, then decide between git restore / git stash
# Never force-push main (see credentials-rotate-runbook.md Git Safety Protocol §13-25)
```

## Sanity assertions before commit

- `git diff --cached --stat` should show ≤ 2 files changed.
- No file outside `docs/` is staged.
- `gitleaks protect --staged` passes (the pre-commit hook will catch
  this too, but assert it explicitly so a misconfigured repo cannot
  sneak through).
