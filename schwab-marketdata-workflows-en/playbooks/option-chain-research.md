# Playbook — Option chain research (single underlying)

| Field             | Value                                                                                |
| ----------------- | ------------------------------------------------------------------------------------ |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                        |
| target_files      | `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md`                                       |
| schwab tools used | `get_quote`, `get_option_expiration_chain`, `get_option_chain`                       |
| max tool calls    | ≤ 6                                                                                   |

## Purpose

Snapshot the option chain for one underlying (e.g. `AAPL`, `QQQ`) for
research / journaling.  Designed to be a single, self-contained note —
not a real-time monitor (use the streaming API for that, which this
server does NOT expose).

## Inputs

- `symbol` — single ticker; reject anything that does not match
  `^[A-Z][A-Z0-9.\-/]{0,9}$` (no indices, no OSI strings).
- `from_date` / `to_date` — optional TZ-aware datetimes for the chain
  window.  Default: today → today + 60 days.

## Pre-flight

Same 5-step checklist as `voo-qqq-tracker-update.md`.

## Steps

1. `get_quote(symbol)` — capture the underlying price for ATM context.
2. `get_option_expiration_chain(symbol)` — list available expiries.
3. Pick up to 2 expiries within `[from_date, to_date]`:
   - the **nearest monthly** (3rd Friday of the next month)
   - the **next quarterly** (Mar/Jun/Sep/Dec)
4. For each picked expiry, call `get_option_chain` with:

   ```text
   contract_type="ALL"
   strike_count=20
   include_underlying_quote=False  # already have it from step 1
   strategy="SINGLE"
   strike_range="NEAR_THE_MONEY"
   from_date=<picked_expiry>
   to_date=<picked_expiry>
   ```

   This produces ~20 strikes around the money for that expiry, both
   calls and puts.
5. Build a markdown report at
   `docs/option-research/<SYMBOL>-<YYYY-MM-DD>.md` containing:
   - underlying snapshot (from step 1)
   - one section per expiry showing a calls/puts table sorted by strike

## Write & commit

```bash
cd ${target_repo}
mkdir -p docs/option-research
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c data/options-${SYMBOL,,}-$(date +%Y%m%d)
fi
git add docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md
git commit -m "data(schwab): ${SYMBOL} option chain research $(date -u +%Y-%m-%d)"
```

## Acceptance criteria

After completion, verify each item:

- [ ] **commit created**: `git -C ${target_repo} log -1 --format="%H %s"`
      prints the latest commit hash + a message with the `data(schwab):` prefix
- [ ] **only files under docs/ modified**:
      every path from `git -C ${target_repo} diff --stat HEAD~1` starts with
      `docs/option-research/` (should be exactly `docs/option-research/${SYMBOL}-<date>.md`)
- [ ] **health_check still valid**:
      `uv run python -m schwab_marketdata_mcp.health` exits 0 and prints `token_state == "valid"`
- [ ] **gitleaks pass**:
      `pre-commit run gitleaks --files docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md`
      exits 0
- [ ] **file head spot-check**:
      `head -50 ${target_repo}/docs/option-research/${SYMBOL}-$(date -u +%Y-%m-%d).md`
      shows the underlying snapshot + at least one expiry section
      (with a calls/puts strike table + a UTC timestamp)

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # undo the commit but keep working-tree changes
# Inspect what changed, then decide between git restore / git stash
# Never force-push main (see credentials-rotate-runbook.md Git Safety Protocol §13-25)
```

## Cautions

- The Greeks (`delta`, `gamma`, `theta`, `vega`) returned by Schwab are
  computed against their pricing model.  **Document the exact moment**
  (UTC + market session) at which the snapshot was taken — values shift
  meaningfully over a single trading hour.
- Chain data is non-redistributable per Schwab ToS.  If the user asks
  to share this note, refuse and remind them per
  `references/tos-snapshot.md`.
