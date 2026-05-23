# Playbook — Shakeout analysis v2 (8-signal scan + AI weekly report)

| Field             | Value                                                                                                                |
| ----------------- | -------------------------------------------------------------------------------------------------------------------- |
| target_repo       | `/opt/workspace/code/kevinkda/stock-personal`                                                                        |
| target_files      | `research/shakeout-YYYY-MM-DD.md` (new); optionally one appended row in `trackers/voo-qqq-tracker.md §10`             |
| schwab tools used | `get_market_hours`, `get_quotes`, `get_price_history`, `get_cache_stats`, optionally `get_streaming_snapshot`        |
| max tool calls    | ≤ 12 (with cache hits, typically 4–6 real Schwab calls)                                                              |
| Model source      | `trackers/voo-qqq-tracker.md §10` (Tang Keyin's private methodology; do not fabricate or redistribute)               |

> **This playbook only runs inside the stock-personal repository.** If
> the cwd is not in that subtree, switch to read-only mode: emit the
> analysis to chat, **never write** to any other repository.

## Model summary (source: voo-qqq-tracker.md §10)

**Bull Market Shakeout Pattern**:

```text
Phase 1: new high → hits resistance
Phase 2: 2-4 day pullback (-0.5% to -1.5%)
Phase 3: RSI drops from 75+ to 65-70 ("repair" but still elevated)
Phase 4: down-day volume contracts (holders refuse to sell)
Phase 5: V-shaped reclaim of prior high
Phase 6: next leg up
```

**8-signal scan table** (§10.3):

| # | Signal                  | Shakeout (HOLD) threshold       | True reversal (SELL) threshold       |
| - | ----------------------- | ------------------------------- | ------------------------------------ |
| 1 | Bull Trend regime       | confidence > 0.9                | flips to Range / Bear                |
| 2 | Price vs MA20           | price ≥ MA20                    | price < MA20                         |
| 3 | Daily / cumulative drop | > -2% or cumulative > -3%   | single day < -3% across multi-days   |
| 4 | Down-day volume         | contracts (vs 10D mean)   | expands (vs 10D mean)         |
| 5 | RSI(14)                 | ≥ 60                            | < 50                                 |
| 6 | Major macro event       | none                            | yes (Fed / geopolitics / earnings)   |
| 7 | VIX                     | < 25                            | ≥ 25 or spiking                      |
| 8 | Open P&L                | < +3%                           | ≥ +3% (consider take-profit; orthogonal to reversal) |

**Decision matrix**:

- Items 1–7 **all on the shakeout column** + item 8 = "no" → **HOLD** (this is a shakeout).
- Items 1–7 with **≥ 3 hits on the reversal column** → **REVIEW / TRIM**.
- Item 8 = "yes" → **consider take-profit** (independent of reversal).
- Otherwise → **default HOLD**.

## Pre-flight (mandatory)

```text
1. get_server_info()                              # version handshake
2. health_check()                                 # token_state must be "valid";
                                                  # also note cache_size_mb / cache_hit_rate_24h
3. get_cache_stats()                              # decide how aggressively we can rely on cache
4. git -C ${target_repo} config --get remote.origin.url
   → must end with kevinkda/stock-personal(.git)?
5. gh repo view kevinkda/stock-personal --json isPrivate -q .isPrivate
   → must be true (else ASK the user; never auto-write)
6. cwd ∈ ${target_repo} subtree?  if not → read-only mode (chat output only)
7. Confirm trackers/voo-qqq-tracker.md §10 still exists and is readable;
   if missing or truncated → STOP and report "shakeout model source missing".
```

## Steps

### Step 1 — Pick the symbols

Defaults to **`["VOO", "QQQ", "SPY"]`** (mirrors voo-qqq-tracker).
The user can also specify **`TQQQ`** / **`COHR`** or any current
watchlist symbol. **Cap at 5 symbols** to stay within the
≤ 12 tool-call budget.

### Step 2 — Pull price history (DuckDB cache first)

For each symbol:

```text
get_price_history(
    symbol=...,
    period_type="MONTH",
    period="THREE_DAYS",      # enough for §10's MA20 and 3-day drop;
                              # historical candles are cached forever
    frequency_type="DAILY",
)
```

> **Cache semantics** (introduced in v0.2 sprint):
>
> - If `_cache_status == "hit"`: candles came from DuckDB; zero Schwab quota used.
> - If `_cache_status == "miss"`: this call wrote to cache; the next request
>   in the same window short-circuits.
> - Candles older than 1 hour are **cached permanently**; no need to refetch.
> - Candles inside the last hour are force-refreshed if older than 60 s,
>   so the §10 model always sees fresh "today" data.

To bypass the cache (e.g. suspected drift), set
`SCHWAB_CACHE_BYPASS=1` in the host environment for one run, then unset it.

### Step 3 — Pull live quotes and VIX

```text
get_quotes(symbols=["VIX", *symbols], fields=["QUOTE", "REGULAR"])
```

`VIX` feeds signal #7; the other quotes drive "price vs MA20" and "open
P&L".

> If `VIX` cannot be quoted directly (some accounts restrict it), try
> `$VIX.X` or `^VIX`. If all fail, mark "VIX unavailable" in the report
> and label signal #7 as `N/A`.

### Step 4 — Run the 8-signal scan locally on DuckDB

**Compute entirely locally** — **no further Schwab calls**. Write a
short Python helper or compute inline. All windowed candles live in the
`price_history_cache` table populated in Step 2 and can be read via
`Cache.query_candles(symbol, start, end)` (see schwab-marketdata-mcp
`cache.py`).

Each symbol produces an **8-row × 4-column** table:

| # | Signal | Threshold | Measured | Status |

That's at most 5 tables for 5 symbols.

### Step 5 — Generate the AI report

Write the following 7 markdown sections to
`${target_repo}/research/shakeout-YYYY-MM-DD.md`:

1. **Frontmatter**: `generated_at` (UTC), `symbols`, `cache_hit_rate`, `mcp_version`.
2. **TL;DR**: single line, e.g. "QQQ 7/8 signals match shakeout → HOLD".
3. **Per-symbol 8-signal tables** (Step 4 output).
4. **Decision matrix**: HOLD / REVIEW / TRIM / TAKE_PROFIT.
5. **Three key insights** (generated from this period's data; do not
   verbatim-copy from §10 historical samples).
6. **Risk callouts**: list the 5 invalidation scenarios from §10.6 and
   whether any triggered this period.
7. **Sources & limitations**: link to `voo-qqq-tracker.md §10`, this run's
   cache hit rate, and the Schwab Market Data SOSA non-redistribution
   declaration.

### Step 6 — Optional: append one row to voo-qqq-tracker.md §10.4

Only with the user's **explicit consent** and only when **VOO or QQQ**
is in the analyzed set, append one new row to the §10.4 history-validation
table. Do not edit any other section.

## Write & commit

```bash
cd ${target_repo}
# Switch to a data branch (avoid polluting main)
if [ "$(git branch --show-current)" = "main" ]; then
    git switch -c research/shakeout-$(date +%Y%m%d)
fi
mkdir -p research
# Step 5 has already written research/shakeout-YYYY-MM-DD.md
git add research/shakeout-$(date +%Y-%m-%d).md
# Only add §10.4 if Step 6 actually edited it
git diff --quiet trackers/voo-qqq-tracker.md \
    || git add trackers/voo-qqq-tracker.md
git commit -m "data(schwab): shakeout-v2 analysis $(date -u +%Y-%m-%d)"
# DO NOT push --force.  Plain push to the research/data branch is fine.
```

## Acceptance criteria

Verify each box by running its command and inspecting the output:

- [ ] **Commit created**: `git -C ${target_repo} log -1 --format="%H %s"` shows
      the latest commit hash + `data(schwab):` prefix
- [ ] **Today's research file exists**:
      `ls ${target_repo}/research/shakeout-$(date +%Y-%m-%d).md`
- [ ] **Only research/ and trackers/voo-qqq-tracker.md changed**: every path in
      `git -C ${target_repo} diff --stat HEAD~1` is under one of those two
- [ ] **Health probe still valid**: `uv run python -m schwab_marketdata_mcp.health`
      exit code = 0
- [ ] **Cache hit rate ≥ 30%**: call `get_cache_stats()` once more at the end;
      `hit_rate_24h` ≥ 0.3 (proves the cache actually relieved Schwab)
- [ ] **gitleaks passes**: `pre-commit run gitleaks --files <changed_files>` exit
      code = 0
- [ ] **Report has all 7 sections**:
      `grep -c '^##' ${target_repo}/research/shakeout-$(date +%Y-%m-%d).md` ≥ 7
- [ ] **No verbatim copy from §10**: spot-check one §10 paragraph; `grep -F`
      should not find a verbatim match in the new report (confirms AI generation,
      not transcription)
- [ ] **`cache.duckdb` row count grew this run (v0.3 sprint Sprint A AC #9)**:
      call `get_cache_stats()` once during §Pre-flight Step 3 and once at Step 6;
      compare `total_rows` (or `price_history_cache_rows`): the scan must write
      at least one new candle, so `total_rows_after - total_rows_before ≥ 1`
      (unless every symbol was a full cache hit, in which case every
      `_cache_status` should be `"hit"`).
      **If rows did not grow AND any `_cache_status == "miss"` → cache write
      silently failed; STOP and report.**

## Rollback

```bash
cd ${target_repo}
git reset --soft HEAD~1   # undo the commit; keep working-tree changes
# Inspect, then either git restore or git stash
# If you really want to discard:
git restore research/shakeout-$(date +%Y-%m-%d).md
git restore trackers/voo-qqq-tracker.md  # only if Step 6 modified it
# Never force-push main.
```

## Failure modes

| Symptom                                                    | Action                                                                                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `voo-qqq-tracker.md §10` missing / truncated                | **STOP**. Report "shakeout model source missing; v2 playbook not implemented". **Never fabricate the model.**       |
| `SchwabAuthError(reason="refresh_token_expired")`          | Stop, ask user to run `auth login_flow`.                                                                            |
| `SchwabRateLimitError`                                     | Wait `retry_after_seconds`, then continue; if it fires twice in a row, STOP and surface to the user.                |
| `gh repo view` fails / repo not private                    | **STOP and refuse to write.** Tell the user; do not bypass.                                                         |
| `get_cache_stats()` reports cache `enabled == false`       | OK to continue, but note in the report "cache disabled, every quote hit Schwab live"; suggest the user enable it.   |
| `research/shakeout-YYYY-MM-DD.md` already exists for today  | Ask the user whether to **overwrite** today's snapshot; default = skip and tell the user.                           |
| VIX data unavailable                                       | Mark signal #7 `N/A`; switch the decision matrix to a 7-item weighting. **Never fabricate a VIX value.**            |
| Step 4 computation fails (e.g. not enough candles for MA20) | Honest "not enough data" in the report; mark that signal `N/A`. **Never zero-fill or forward-fill.**                |
| **DuckDB lock conflict (another process is using `cache.duckdb`)** | **(v0.3 sprint AC #10)** Wait 5 s and retry once; if still locked → set `SCHWAB_CACHE_BYPASS=1` for one run (live API path) and note `cache locked, bypassed` in the report frontmatter. **Never force-delete the `.lock` file** — that will break concurrent refresh-token rotation. |
