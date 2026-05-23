---
name: schwab-marketdata-ops-en
compatible_mcp_version: ">=0.2,<0.3"
language_directive: "Always respond to the user in English."
auto_activate: false
activation_handshake: "get_server_info -> health_check"
compatibility: >-
  Designed for Cursor IDE >=0.45, Claude Code >=1.0, Kiro CLI >=0.1,
  Cline >=3.x, Roo Code, and other skills-compatible agents.
dependencies:
  mcp_server: "schwab-marketdata-mcp"
  external_runtime: ["uv", "python>=3.10"]
  optional_runtime: ["gh CLI (for workflows skill)", "jq (for shell ad-hoc)"]
governance:
  data_classification: "non-redistributable (Schwab Market Data)"
  written_artifacts_must_stay_in: "private repositories"
  prohibited_force_push_targets: ["main", "mainline"]
  # "master" no longer included; GitHub default has been "main" since 2020. Legacy repos should be migrated.
description: |
  Use when the user wants to call Schwab Market Data Production via the
  schwab-marketdata-mcp server, troubleshoot OAuth or 7-day refresh-token
  expiry, recover from 401/429/5xx errors, or look up the exact input/output
  schema for any of the 12 market-data tools (quotes×2, price_history,
  option_chain×2, market_hours×2, movers, search_instruments,
  get_instrument_by_cusip, health_check, get_server_info).
  Use this skill instead of schwab-marketdata-workflows-en when the request
  is about a single MCP tool call or troubleshooting (not a multi-step
  playbook).
  Triggers on "Schwab quote", "Schwab price history", "Schwab option
  chain", "Schwab token expired", "reauthorize Schwab",
  "Schwab API error".
  For these scenarios use this skill; always respond to the user in English.
---

# schwab-marketdata-ops-en

> **Responsibility disclaimer**: This skill drives the Schwab Market Data
> Production API. Users are required to read
> <https://www.schwab.com/legal/terms> and
> <https://developer.schwab.com/legal>, and bear sole responsibility for
> compliance of their usage. The authors of `schwab-marketdata-mcp` and
> `schwab-marketdata-skill` are not liable for any usage that violates the
> Schwab Terms of Service.

## Activation handshake (run first)

When activating this skill, the **first step** must be a call to
`get_server_info` to confirm that the returned `server_version` falls
within the frontmatter `compatible_mcp_version` range:

```text
get_server_info()
→ { "server_version": "0.1.x", "supported_tools": [...12 names...] }
```

If the version does not match or the call fails: **stop immediately**,
tell the user to upgrade either `schwab-marketdata-mcp` or this skill,
and **do not** continue any business calls.

Full handshake (including token health check):

```text
1. get_server_info()  → verify server_version ∈ compatible_mcp_version
2. health_check()     → verify token_state == "valid"
                       and token_expires_in_days >= 0.5
3. If either step fails → stop immediately and follow the references
   to repair before continuing.
```

## Quick Start — 7 steps from zero to hello-world

For a first-time onboarding or a new machine, read the following 7 step
files in order:

| Step | File | Expected outcome |
| ---- | ---- | ---------------- |
| 1 | [`references/quick-start/step-1-developer-portal-app.md`](references/quick-start/step-1-developer-portal-app.md) | Schwab Developer Portal app created, App Key / Secret in hand |
| 2 | [`references/quick-start/step-2-credentials-env.md`](references/quick-start/step-2-credentials-env.md) | `.env` populated (chmod 600), pre-commit hooks installed |
| 3 | [`references/quick-start/step-3-first-oauth.md`](references/quick-start/step-3-first-oauth.md) | `token.json` written to disk (chmod 600) |
| 4 | [`references/quick-start/step-4-token-health-check.md`](references/quick-start/step-4-token-health-check.md) | `health` module exits 0, `token_state == "valid"` |
| 5 | [`references/quick-start/step-5-first-mcp-tool-call.md`](references/quick-start/step-5-first-mcp-tool-call.md) | Minimal Python MCP client successfully calls `get_quote("VOO")` |
| 6 | [`references/quick-start/step-6-cursor-integration.md`](references/quick-start/step-6-cursor-integration.md) | `~/.cursor/mcp.json` registered, agent can invoke all 12 tools |
| 7 | [`references/quick-start/step-7-cron-launchd-setup.md`](references/quick-start/step-7-cron-launchd-setup.md) | cron / launchd health probes enabled, desktop notification channel verified |

## Common usage scenarios

Following the helis "I want to..." routing pattern, dispatch directly
to the right tool and reference doc based on user intent.

### "I want a real-time quote"

| Scenario | What to use | Notes |
| -------- | ----------- | ----- |
| Single stock / ETF / index | `get_quote("AAPL")` / `get_quote("$SPX")` | symbol must be UPPERCASE; indexes need a `$` prefix |
| Batch (≤ 50) | `get_quotes(symbols=[…])` | beyond 50, batch on the client side, otherwise `SchwabValidationError(field="symbols")` |
| Option contract | `get_quote("AAPL  240119C00170000")` | **OSI 21 chars**: 6-char root (space-padded) + YYMMDD + C/P + 8-digit strike(×1000) |

→ Full schema in [`references/tools/tool-reference-quotes.md`](references/tools/tool-reference-quotes.md).

### "I want to research an option chain"

1. `get_option_expiration_chain(symbol)` — fetch the list of available expirations first
2. `get_option_chain(symbol, contract_type=…, strike_count=…, strike_range=…)` — pull concrete contracts by ATM/OTM/ITM
3. Multi-step research workflow → switch to the `schwab-marketdata-workflows-en` skill's `option-chain-research.md` playbook

→ Schema in [`references/tools/tool-reference-options.md`](references/tools/tool-reference-options.md);
Greeks freshness covered in the playbook's Cautions section and
[`references/concepts/osi-option-symbol.md`](references/concepts/osi-option-symbol.md).

### "Token expired, what now?"

```text
1. health_check()
   → inspect token_state ∈ {"valid","missing","malformed","insecure_perms"}
   → inspect token_expires_in_days (< 0.5 strongly suggests immediate reauthorize)
2. If SchwabAuthError(reason="refresh_token_expired" | "token_not_initialized"):
   uv run python -m schwab_marketdata_mcp.auth login_flow   # default
   # or manual_flow (headless / SSH-only / WSL2)
3. Re-run health_check() to confirm token_state == "valid"
```

→ Full mapping table and step-by-step remediation in
[`references/troubleshooting/auth-overview.md`](references/troubleshooting/auth-overview.md);
OAuth flow walkthrough in
[`references/oauth/oauth-overview.md`](references/oauth/oauth-overview.md);
token lifecycle in
[`references/oauth/oauth-token-lifecycle.md`](references/oauth/oauth-token-lifecycle.md).

### "Got rate-limited, what now?"

| Symptom | Remediation |
| ------- | ----------- |
| `SchwabRateLimitError(retry_after_seconds=N)` | Wait N seconds and retry; if it happens twice in a row, surface to the user |
| stderr emits `{"event":"rate_limit_warning","remaining":<20}` | Switch bulk requests to `get_quotes` (50 per call); or lower `SCHWAB_RATE_LIMIT_PER_MIN` |
| 0 slots, raises immediately | Apply retry-with-backoff on the agent side (schwab-py already retries `SCHWAB_MAX_RETRIES` times internally) |

→ Token-bucket behavior and triage in
[`references/operations/rate-limit-token-bucket.md`](references/operations/rate-limit-token-bucket.md);
4-symptom rate-limit triage in
[`references/troubleshooting/rate-limit-overview.md`](references/troubleshooting/rate-limit-overview.md).

### "I want to inspect server health"

```text
get_server_info()  → server_version / mcp_sdk_version / schwab_py_version / supported_tools
health_check()     → token_state / token_expires_in_days / rate_limit_remaining_per_min / recent_error_count_24h
```

The two together answer "Is the MCP server healthy, is the token valid,
and have we exhausted the rate limit?" in under 30 seconds.

→ Schema in [`references/tools/tool-reference-meta.md`](references/tools/tool-reference-meta.md).

### "I want candlesticks / historical data"

```text
get_price_history(symbol, period_type, period?, frequency_type, frequency?, ...)
```

The `(period_type, period, frequency_type, frequency)` 4-tuple only
accepts a **restricted set of combinations** — illegal combinations are
silently 400'd by the server. The MCP server pre-rejects them at the
Pydantic layer.

→ Schema + legal-combination table in
[`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md);
Cartesian-product error remediation in
[`references/troubleshooting/validation-pricehistory-cartesian.md`](references/troubleshooting/validation-pricehistory-cartesian.md).

### "I want instrument metadata / company fundamentals"

| Scenario | What to use |
| -------- | ----------- |
| Known ticker → metadata | `search_instruments(symbols=["AAPL"], projection="SYMBOL_SEARCH")` |
| Known ticker → fundamentals | `search_instruments(symbols=["AAPL"], projection="FUNDAMENTAL")` |
| Known 9-digit CUSIP | `get_instrument_by_cusip(cusip="037833100")` |
| Fuzzy company-name lookup | `search_instruments(symbols=["TESLA"], projection="DESCRIPTION_SEARCH")` |

→ Schema in [`references/tools/tool-reference-instruments.md`](references/tools/tool-reference-instruments.md).

### "I want top movers / unusual activity today"

```text
get_movers(index="DJI"|"COMPX"|"SPX"|..., sort_order=..., frequency=...)
```

The `index` enum value must be passed as the **enum name** (`"DJI"`),
not the wire value (`"$DJI"`).

→ Schema + enum reference in [`references/tools/tool-reference-movers.md`](references/tools/tool-reference-movers.md).

### "I want to call this from my own Python / TypeScript / Rust app"

| Client | File |
| ------ | ---- |
| Python (mcp SDK) | [`references/integration/python-mcp-client.md`](references/integration/python-mcp-client.md) |
| TypeScript / Node | [`references/integration/typescript-mcp-client.md`](references/integration/typescript-mcp-client.md) |
| Rust (rmcp or hand-rolled) | [`references/integration/rust-mcp-client.md`](references/integration/rust-mcp-client.md) |
| Shell + jq pipe | [`references/integration/cli-jq-pipe.md`](references/integration/cli-jq-pipe.md) |

## Data coverage clarifications

### `get_price_history` is the candlestick / kline endpoint

If you're looking for OHLCV bars (candles, klines, candlesticks),
`get_price_history` is the tool. The response carries a `candles[]`
array, each entry exposing `open` / `high` / `low` / `close` / `volume`
/ `datetime` (epoch milliseconds).

Supported granularity comes from the `(period_type, frequency_type,
frequency)` triple:

- `period_type=DAY`: `MINUTE` × {1, 5, 10, 15, 30} (~48 days for 1-min,
  ~9 months for 5–30 min).
- `period_type=MONTH`: `DAILY` / `WEEKLY` (up to 6 months).
- `period_type=YEAR`: `DAILY` / `WEEKLY` / `MONTHLY` (**up to 20
  years**).
- `period_type=YEAR_TO_DATE`: `DAILY` / `WEEKLY` (year-to-date).

Sub-minute candles (seconds, ticks) are not in the Schwab Market Data
API surface.

→ Full legal-combination table + Cartesian-product error remediation in
[`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md)
and the MCP repo's
[README → "Data coverage clarifications"](https://github.com/kevinkda/schwab-marketdata-mcp/blob/main/README.md#data-coverage-clarifications).

### What the Schwab Market Data API does NOT provide

The following data is **architecturally unavailable** through the Schwab
Market Data Production API and would require a third-party provider:

- **Time & sales / tape (trade-level)** — not in REST or Streaming
  since Schwab's 2024 API migration removed the `TIMESALE_*` services.
- **Tick-by-tick history** — not in the Schwab API.
- **Level 2 historical snapshots** — Streaming only, no REST history.
- **Fundamental / earnings time series** (EPS history, revenue
  history, etc.) — `quotes` carry FUNDAMENTAL fields but there is **no**
  historical endpoint.
- **News / SEC filings** — not in the Market Data API.

Recommended third-party providers (Polygon.io, Tiingo, Alpaca,
Databento, FMP, SEC EDGAR) for each data class are listed in the MCP
repo's
[README → "Data coverage clarifications"](https://github.com/kevinkda/schwab-marketdata-mcp/blob/main/README.md#data-coverage-clarifications).

### Trader API is out of scope

**Trader API endpoints** (account, orders, transactions, positions)
are explicitly out of scope — this skill covers **read-only Market
Data only**. If the user asks to place an order or modify positions,
refuse immediately and point them at the MCP README's "Responsible
use" section.

## Decision tree — pick the right tool

| User intent                                | What to use                                              |
| ------------------------------------------ | -------------------------------------------------------- |
| Single stock/ETF/index spot price          | `get_quote(symbol="AAPL")`                               |
| One-shot multi-symbol quotes (≤50)         | `get_quotes(symbols=[...])`                              |
| Historical candles / OHLC                  | `get_price_history(symbol, period_type, …)`              |
| Option chain snapshot                      | `get_option_chain(symbol, contract_type=…)`              |
| Option expiration list                     | `get_option_expiration_chain(symbol)`                    |
| Multi-market open/close status             | `get_market_hours(markets_list=[…])`                     |
| Single-market open/close status            | `get_market_hour_single(market_id)`                      |
| Today's top movers                         | `get_movers(index, sort_order)`                          |
| Fuzzy instrument lookup by ticker          | `search_instruments(symbols, projection)`                |
| Exact lookup by 9-digit CUSIP              | `get_instrument_by_cusip(cusip)`                         |
| Inspect token state / error counters       | `health_check()`                                         |
| Get server metadata (version, 12 tools)    | `get_server_info()`                                      |

**Enum values** must always use the **enum names** defined in
`models.py` (e.g. `"VOLUME"`, `"NASDAQ"`, `"DAY"`); the MCP server
internally translates them into schwab-py wire values.

## Key Concepts

| Term | Definition |
| ---- | ---------- |
| **access_token** | Schwab OAuth bearer token, valid for **90 minutes**; schwab-py auto-renews it before each API call, so the agent never has to think about it. |
| **refresh_token** | **rotate-on-use**: every refresh issues a new refresh_token, with a hard **7-day** lifetime. After expiry you must run `login_flow` again — there is no shortcut (Schwab OAuth is designed this way). |
| **TokenState** | One of 4 enums returned by `health_check()`: `valid` (usable) / `missing` (no token.json) / `insecure_perms` (file mode is not 600/700) / `malformed` (JSON corrupt or missing fields). The first three are fixed by `auth login_flow`; the last typically requires backing up and deleting token.json first. |
| **SchwabAuthError reason** | A 6-way enum attached to auth failures during business calls: `refresh_token_expired_soon` / `refresh_token_expired` / `token_not_initialized` / `token_corrupted` / `insecure_token_perms` / `callback_url_mismatch`. Each reason has its own 5-section remediation page in [`references/troubleshooting/`](references/troubleshooting/). |
| **rate_limit_bucket** | The MCP server uses a **token bucket + sliding window** (capacity = `SCHWAB_RATE_LIMIT_PER_MIN`, default 120) instead of `asyncio.Semaphore`. Difference: a Semaphore would hold its slot during retry sleep, blocking other concurrent tools; the token bucket releases the slot during sleep, letting other tools proceed. |
| **OSI option symbol** | A 21-character fixed format: `{ROOT:6}{YYMMDD:6}{C\|P:1}{STRIKE×1000:8}`, with the root right-padded with spaces if shorter than 6 chars. Example: `"AAPL  240119C00170000"` = AAPL 2024-01-19 Call $170.00; `"BRK/B 240419P00350000"` (contains `/`). Pass this directly to `get_quote`. |
| **pricehistory cartesian product** | Schwab only accepts a **restricted set of combinations** for the `(period_type, period, frequency_type, frequency)` tuple; illegal combinations silently return 400. The MCP server pre-rejects them at the Pydantic layer to avoid wasting billed quota. The full legal-combination table lives in [`references/tools/tool-reference-price-history.md`](references/tools/tool-reference-price-history.md). |
| **Pydantic Literal: enum name vs wire value** | The public API always takes the **enum name** (e.g. `MoversIndex.DJI` = `"DJI"`); the MCP server translates internally to the schwab-py wire value (e.g. `"$DJI"`). This translation layer means the agent never has to remember prefix characters (`$` / lowercase / mixed case). **Never** pass a wire value directly — it triggers `SchwabValidationError`. |
| **Activation handshake** | The two mandatory steps after skill activation: `get_server_info` to verify version compatibility, `health_check` to verify token state. Either failure stops the flow immediately — no silent fallback allowed. |
| **error normalization** | All schwab-py exceptions are wrapped by the server into `{"error": "Schwab*Error", ...}` dicts and returned to the caller — they **do not** propagate as exceptions through the MCP protocol. The agent must always check the `error` field before reading the payload. |
| **non-redistributable** | Schwab Market Data is non-redistributable; any markdown / report writes must stay inside private repositories (the workflows skill enforces this with `gh repo view --json isPrivate`). |

## Architecture overview

```text
┌────────────────────┐
│  AI agent (this    │  Cursor / Claude / Kiro / custom SDK clients
│  skill activates)  │
└────────┬───────────┘
         │ MCP JSON-RPC over stdio
         ▼
┌────────────────────────────────────────────┐
│  schwab-marketdata-mcp (separate repo)     │
│  Pydantic → token-bucket → schwab-py       │
└──────────┬─────────────────────────────────┘
           │ HTTPS Bearer access_token
           ▼
┌────────────────────────┐
│ Schwab Market Data API │ api.schwabapi.com
└────────────────────────┘
```

Full architecture, the 5 core components, data flow, and trust
boundaries are in
[`references/concepts/architecture-overview.md`](references/concepts/architecture-overview.md).

## Glossary

A cross-domain glossary spanning OAuth / MCP / Schwab API / rate
limiting / error handling lives in
[`references/concepts/glossary.md`](references/concepts/glossary.md).

The 11 most critical concepts, each with a "why was it designed this
way" explanation, lives in
[`references/concepts/key-concepts.md`](references/concepts/key-concepts.md).

## Schema cheat-sheet (full per-family schemas under `references/tools/`)

```text
get_quote(symbol: str, fields?: list[QuoteFields])  # symbol must be UPPERCASE; "$SPX"/"AAPL  240119C00170000" also OK
get_quotes(symbols: list[str], fields?, indicative?)  # ≤50 symbols / call

get_price_history(
  symbol, period_type, period?, frequency_type, frequency?,
  start_datetime?, end_datetime?, need_extended_hours_data?, need_previous_close?
)
# Cartesian-product rules in references/tools/tool-reference-price-history.md.  TZ-aware datetimes only.

get_option_chain(symbol, contract_type?, strike_count?, ...)  # see references
get_option_expiration_chain(symbol)
get_market_hours(markets_list: list[MarketEnum], date?)
get_market_hour_single(market_id, date?)
get_movers(index, sort_order?, frequency?)
search_instruments(symbols, projection)
get_instrument_by_cusip(cusip: 9 alphanumerics)
health_check()
get_server_info()
```

## Error normalization

All business tools **return a dict instead of raising** when an error
occurs (so the agent always sees structured data):

| `error` field               | Remediation                                                                              |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `SchwabAuthError`           | Inspect `reason` → [`references/troubleshooting/auth-overview.md`](references/troubleshooting/auth-overview.md) routing table (6 reasons, each with its own sub-doc). |
| `SchwabRateLimitError`      | Retry after `retry_after_seconds`, or lower `SCHWAB_RATE_LIMIT_PER_MIN`. See [`references/troubleshooting/rate-limit-overview.md`](references/troubleshooting/rate-limit-overview.md). |
| `SchwabTransientError`      | Schwab 5xx / network jitter; safe to retry briefly, but escalate to the user if it persists. See [`references/troubleshooting/transient-errors.md`](references/troubleshooting/transient-errors.md). |
| `SchwabValidationError`     | Bad input parameter; see [`references/troubleshooting/validation-overview.md`](references/troubleshooting/validation-overview.md). |

The full triage index lives in [`references/error-recovery.md`](references/error-recovery.md).

## Compatibility matrix

For per-client coverage of this skill's frontmatter fields, see the
"Compatibility matrix" section in the repo root `README.md` (5 clients
× 8 fields). Key convention: every non-standard frontmatter field
(`compatible_mcp_version` / `required_workspace` / `language_directive`
/ `auto_activate` / `activation_handshake` / `compatibility` /
`dependencies` / `governance`) is **only a documented constraint** —
the actual enforcement lives in the runtime checks of this SKILL.md
body (`get_server_info` version handshake + `cwd` validation +
language directive). Even if a client ignores these fields, the skill
still behaves correctly.

## FAQ

A 25+ entry FAQ lives in
[`references/faq.md`](references/faq.md), grouped into 7 categories:
"getting started / install & registration / OAuth / rate limiting /
calling / security / skill / failures".

## Reference index

A full subject-categorized reference index, mirroring the multi-level
table layout of the helis SKILL.md.

### Quick Start (7 files)

| File | Description |
| ---- | ----------- |
| [quick-start/step-1-developer-portal-app.md](references/quick-start/step-1-developer-portal-app.md) | Register a Schwab Developer Portal app, obtain App Key / Secret |
| [quick-start/step-2-credentials-env.md](references/quick-start/step-2-credentials-env.md) | Populate `.env` (mode 600), install pre-commit hook |
| [quick-start/step-3-first-oauth.md](references/quick-start/step-3-first-oauth.md) | First-time OAuth flow (login_flow / manual_flow) |
| [quick-start/step-4-token-health-check.md](references/quick-start/step-4-token-health-check.md) | Verify the token actually works via the `health` module |
| [quick-start/step-5-first-mcp-tool-call.md](references/quick-start/step-5-first-mcp-tool-call.md) | Minimal MCP client: `health_check` + `get_quote("VOO")` |
| [quick-start/step-6-cursor-integration.md](references/quick-start/step-6-cursor-integration.md) | Register with Cursor / Claude `~/.cursor/mcp.json` |
| [quick-start/step-7-cron-launchd-setup.md](references/quick-start/step-7-cron-launchd-setup.md) | Automate health probes via cron / launchd / systemd |

### Tools (1 index + 7 family files)

| File | Description |
| ---- | ----------- |
| [tools/index.md](references/tools/index.md) | 12-tool routing + cross-tool conventions |
| [tools/tool-reference-quotes.md](references/tools/tool-reference-quotes.md) | `get_quote` / `get_quotes` full schema |
| [tools/tool-reference-price-history.md](references/tools/tool-reference-price-history.md) | `get_price_history` + cartesian-product legal table |
| [tools/tool-reference-options.md](references/tools/tool-reference-options.md) | `get_option_chain` / `get_option_expiration_chain` |
| [tools/tool-reference-markets.md](references/tools/tool-reference-markets.md) | `get_market_hours` / `get_market_hour_single` |
| [tools/tool-reference-movers.md](references/tools/tool-reference-movers.md) | `get_movers` |
| [tools/tool-reference-instruments.md](references/tools/tool-reference-instruments.md) | `search_instruments` / `get_instrument_by_cusip` |
| [tools/tool-reference-meta.md](references/tools/tool-reference-meta.md) | `health_check` / `get_server_info` |

### OAuth (6 files)

| File | Description |
| ---- | ----------- |
| [oauth/oauth-overview.md](references/oauth/oauth-overview.md) | End-to-end 3-legged OAuth flow + mode decision tree |
| [oauth/oauth-login-flow.md](references/oauth/oauth-login-flow.md) | `login_flow` (default) walkthrough |
| [oauth/oauth-manual-flow.md](references/oauth/oauth-manual-flow.md) | `manual_flow` (headless / SSH-only) walkthrough |
| [oauth/oauth-self-host-callback.md](references/oauth/oauth-self-host-callback.md) | Self-hosted callback endpoint (advanced) |
| [oauth/oauth-token-lifecycle.md](references/oauth/oauth-token-lifecycle.md) | access_token / refresh_token / OAuth code lifecycle |
| [oauth/oauth-callback-mismatch.md](references/oauth/oauth-callback-mismatch.md) | 9 forms of callback URL mismatch with detailed triage |

### Concepts (4 files)

| File | Description |
| ---- | ----------- |
| [concepts/architecture-overview.md](references/concepts/architecture-overview.md) | 5 core components, data flow, trust boundaries |
| [concepts/glossary.md](references/concepts/glossary.md) | Cross-domain glossary (OAuth / MCP / Schwab API / rate limit / error / workflow / security / health probe) |
| [concepts/key-concepts.md](references/concepts/key-concepts.md) | The 11 most critical concepts, with "why was it designed this way" deep dives |
| [concepts/osi-option-symbol.md](references/concepts/osi-option-symbol.md) | OSI 21-char fixed format encoding / decoding / 4 typical violations |

### Integration (4 files)

| File | Description |
| ---- | ----------- |
| [integration/python-mcp-client.md](references/integration/python-mcp-client.md) | Write an MCP client with the `mcp` Python SDK (long-lived sessions included) |
| [integration/typescript-mcp-client.md](references/integration/typescript-mcp-client.md) | Write a Node / Next.js client with `@modelcontextprotocol/sdk` |
| [integration/rust-mcp-client.md](references/integration/rust-mcp-client.md) | Use `rmcp` or hand-roll stdio + JSON-RPC |
| [integration/cli-jq-pipe.md](references/integration/cli-jq-pipe.md) | Pipe stdin/stdout directly with shell + jq |

### Troubleshooting (17 files)

| File | Description |
| ---- | ----------- |
| [troubleshooting/auth-overview.md](references/troubleshooting/auth-overview.md) | Top-level error-type routing (4 classes × multiple reasons) |
| [troubleshooting/auth-token-states.md](references/troubleshooting/auth-token-states.md) | Remediation and state machine for the 4 `token_state` values |
| [troubleshooting/auth-refresh-expiring-soon.md](references/troubleshooting/auth-refresh-expiring-soon.md) | reason=`refresh_token_expired_soon` (< 12h warning) |
| [troubleshooting/auth-refresh-expired.md](references/troubleshooting/auth-refresh-expired.md) | reason=`refresh_token_expired` (already expired) |
| [troubleshooting/auth-token-not-initialized.md](references/troubleshooting/auth-token-not-initialized.md) | reason=`token_not_initialized` (first install) |
| [troubleshooting/auth-token-corrupted.md](references/troubleshooting/auth-token-corrupted.md) | reason=`token_corrupted` (JSON damaged) |
| [troubleshooting/auth-insecure-perms.md](references/troubleshooting/auth-insecure-perms.md) | reason=`insecure_token_perms` (permission issue) |
| [troubleshooting/auth-callback-url-mismatch.md](references/troubleshooting/auth-callback-url-mismatch.md) | reason=`callback_url_mismatch` (OAuth phase) |
| [troubleshooting/rate-limit-overview.md](references/troubleshooting/rate-limit-overview.md) | 4-symptom rate-limit triage |
| [troubleshooting/rate-limit-429.md](references/troubleshooting/rate-limit-429.md) | Schwab server-side 429 |
| [troubleshooting/rate-limit-token-bucket-empty.md](references/troubleshooting/rate-limit-token-bucket-empty.md) | Local token bucket at 0 slots |
| [troubleshooting/rate-limit-warning-stderr.md](references/troubleshooting/rate-limit-warning-stderr.md) | `rate_limit_warning` warning (still successful) |
| [troubleshooting/rate-limit-no-retry-after.md](references/troubleshooting/rate-limit-no-retry-after.md) | 429 missing `Retry-After` header (rare) |
| [troubleshooting/validation-overview.md](references/troubleshooting/validation-overview.md) | Pydantic input-validation routing |
| [troubleshooting/validation-symbol.md](references/troubleshooting/validation-symbol.md) | symbol regex mismatch |
| [troubleshooting/validation-pricehistory-cartesian.md](references/troubleshooting/validation-pricehistory-cartesian.md) | price history cartesian product illegal |
| [troubleshooting/validation-batch-50.md](references/troubleshooting/validation-batch-50.md) | `get_quotes` over-50 symbols |
| [troubleshooting/validation-osi-format.md](references/troubleshooting/validation-osi-format.md) | OSI option format wrong |
| [troubleshooting/transient-errors.md](references/troubleshooting/transient-errors.md) | `SchwabTransientError` (5xx / 4xx edge cases) |

### Operations (3 files)

| File | Description |
| ---- | ----------- |
| [operations/rate-limit-token-bucket.md](references/operations/rate-limit-token-bucket.md) | Token-bucket implementation deep dive + tuning |
| [operations/observability-and-caching.md](references/operations/observability-and-caching.md) | server.log / health fields + agent-side caching strategy |
| [operations/multi-machine-multi-account.md](references/operations/multi-machine-multi-account.md) | Correct patterns for multi-machine / multi-account setups |

### Top-level (5 files)

| File | Description |
| ---- | ----------- |
| [error-recovery.md](references/error-recovery.md) | Error-system overview + decision flow |
| [rate-limits-and-paging.md](references/rate-limits-and-paging.md) | Rate limit + paging combined |
| [credentials-rotate-runbook.md](references/credentials-rotate-runbook.md) | Credential-leak emergency runbook (reset Schwab Secret first, then clean repo) |
| [tos-snapshot.md](references/tos-snapshot.md) | Schwab ToS key excerpts (non-redistributable) |
| [faq.md](references/faq.md) | 25+ FAQ quick lookup |
