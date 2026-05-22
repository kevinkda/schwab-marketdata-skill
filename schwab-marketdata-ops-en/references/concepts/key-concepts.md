# Key concepts

> The 11 concepts that most often trip up agents and developers,
> explained in depth. The Glossary is a dictionary-style quick lookup;
> this file gives the "why was it designed this way".

## 1. access_token vs. refresh_token vs. OAuth code

Three tokens, three lifetimes, three rotation behaviors. The most
common beginner confusion: thinking access_token expiring at 90
minutes means having to re-run OAuth. In reality, schwab-py uses the
refresh_token to auto-renew the access_token before it expires —
**fully transparent**. **Human intervention is only required** when
the refresh_token's 7-day lifetime expires; at that point you must
re-run `auth login_flow`.

See [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md).

## 2. The 4 TokenStates and the 6 reasons

`token_state` returned by `health_check()` describes **local file
state** (4 values):

- `valid` — file exists, JSON valid, all fields present, mode correct
- `missing` — file does not exist
- `malformed` — JSON corrupt / fields missing
- `insecure_perms` — mode is not `600` / `700`

Whereas `SchwabAuthError(reason=...)` describes **business-call failure
causes** (6 values):

- `refresh_token_expired_soon`, `refresh_token_expired`
- `token_not_initialized`, `token_corrupted`
- `insecure_token_perms`, `callback_url_mismatch`

Relationship: `token_state` looks at the on-disk artifact;
`reason` looks at runtime API call results. The first 5 reasons can
all be repaired by `auth login_flow`; the last requires fixing `.env`
first.

See [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md) and
[`../troubleshooting/auth-overview.md`](../troubleshooting/auth-overview.md).

## 3. token-bucket vs. `asyncio.Semaphore`

The server uses a **token bucket + sliding window** rather than
`asyncio.Semaphore` for rate limiting — a deliberate choice:

| Implementation | Behavior | Drawback |
| -------------- | -------- | -------- |
| `asyncio.Semaphore` | If no slot is available, await | Holds the slot during retry sleep, **blocking** other concurrent tools |
| **token-bucket** (current choice) | If no slot is available, raise `SchwabRateLimitError` immediately | The agent is responsible for retry pacing |

Token-bucket advantage: **a single slow tool does not block other
concurrent tools**. Cost: the agent must implement exponential
backoff; do not assume the server will wait automatically.

See [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md).

## 4. OSI option symbol (21-char fixed format)

`{ROOT:6}{YYMMDD:6}{C|P:1}{STRIKE×1000:8}` — must be **exactly 21
characters**.

- The root is right-padded with spaces if shorter than 6 characters:
  `AAPL` → `"AAPL  "`, `BRK/B` → `"BRK/B "`.
- Date `YYMMDD`: 2024-01-19 → `240119`.
- C/P: `C` for call, `P` for put.
- Strike: dollars × 1000, 8-digit integer: $170 → `00170000`,
  $3.5 → `00003500`.

Full examples:

```text
"AAPL  240119C00170000"   # AAPL 2024-01-19 Call $170.00
"BRK/B 240419P00350000"   # BRK/B 2024-04-19 Put $350.00
"SPY   251219C00500000"   # SPY  2025-12-19 Call $500.00 (note 3 spaces after SPY)
```

OSI symbols can be passed directly to `get_quote` / `get_quotes`, but
**not** to `get_option_chain` (which only accepts a stock/ETF
underlying).

## 5. `get_price_history` cartesian product

The `(period_type, period, frequency_type, frequency)` 4-tuple only
accepts a **restricted set of combinations**; illegal combinations are
silently 400'd by the Schwab server. The MCP server pre-rejects them
at the Pydantic layer.

| period_type    | compatible frequency_type      |
| -------------- | ------------------------------ |
| `DAY`          | **only** `MINUTE`              |
| `MONTH`        | `DAILY` / `WEEKLY`             |
| `YEAR`         | `DAILY` / `WEEKLY` / `MONTHLY` |
| `YEAR_TO_DATE` | `DAILY` / `WEEKLY`             |

Full combination table in [`../tools/tool-reference-price-history.md`](../tools/tool-reference-price-history.md).

## 6. Pydantic Literal enum names vs. schwab-py wire values

The public API **always** takes enum names (`"VOLUME"`, `"NASDAQ"`,
`"DJI"`); **do not** pass schwab-py wire values (`"$DJI"`, `"day"`).
The MCP server translates internally.

Design rationale: the agent should not need to remember prefix
characters (`$` / lowercase / mixed case). Passing a wire value
directly triggers `SchwabValidationError`.

The full enum list lives in `models.py`, distributed by family across
[`../tools/tool-reference-*.md`](../tools/index.md).

## 7. Error normalization

All exceptions thrown by schwab-py are wrapped by the server into
`{"error": "Schwab*Error", ...}` **dicts and returned**, **not**
propagated as exceptions through the MCP protocol. Reasons:

1. The agent processes structured data in a language-agnostic way,
   without depending on any specific language's exception mechanism.
2. The MCP protocol's error layer is reserved for protocol-level
   failures (malformed JSON-RPC, etc.), not business failures.
3. Routing tables like `error_recovery.md` can match the `error`
   field value precisely.

The agent must **always check the `error` field first** before
reading the payload.

## 8. rotate-on-use refresh_token

Every refresh issues a new refresh_token and invalidates the old
immediately. Consequences:

- **Cannot** copy token.json across machines — whichever side
  refreshes first invalidates the other.
- **Cannot** roll back token.json to a backup from a few hours ago —
  the old RT has been rotated.
- **Every machine, every account** must run OAuth separately.

This differs from some other OAuth implementations (e.g. Google APIs
do not rotate refresh_token by default). Do not rely on the intuition
"it should work across machines."

## 9. The hard 7-day lifetime

The refresh_token is server-side invalidated 7 days after **first
issuance**, regardless of whether it was used. This means full
automation (no human in the loop) is **impossible** — that's how
Schwab designed it.

Practical advice: cron / launchd at every 4h + Sunday 20:00 +
Wednesday 21:00 + desktop notifications when
`token_expires_in_days < 12h` + a desktop marker file. See
[Quick Start Step 7](../quick-start/step-7-cron-launchd-setup.md).

## 10. Token-path allow-list + cloud-sync detection

The server refuses tokens persisted outside the allow-list subtrees.
Reasons:

- Prevent accidentally writing tokens to `~/Desktop` or shared drives.
- Prevent tokens from landing in iCloud / Dropbox / OneDrive sync
  drives (during sync the token may be momentarily plaintext on the
  cloud server, and rotate-on-use is fundamentally incompatible with
  cross-machine sync).

Allowed roots: `~/.local/state` and `~/.config`. Use `--config-dir`
to switch between subdirectories; bypassing cloud-sync detection
requires the explicit `--i-understand-cloud-sync-risk` flag.

## 11. Activation handshake (mandatory first step)

The first thing after skill activation must be:

```text
get_server_info()  → verify server_version ∈ compatible_mcp_version
health_check()     → verify token_state == "valid"
```

Why these two tools are mandatory:

- `get_server_info`: ensures the skill documentation matches the
  server implementation version (avoids the agent using stale enum
  names / field names).
- `health_check`: ensures the token is actually usable, so the agent
  doesn't run a long string of business calls only to discover the
  token expired 7 days ago.

If the version doesn't match or the token isn't `valid`, the skill
must **stop immediately** and tell the user the specific remediation
(no silent fallback).

## What not to do

- **Do not** skip the activation handshake and jump straight to
  business tools.
- **Do not** re-validate symbols with regex on the agent side — the
  server already does it.
- **Do not** assume independence in multi-agent concurrency — the
  token bucket is shared at the server-process level.
- **Do not** copy token.json to a coworker / cross-machine sync.
- **Do not** treat the 7-day expiry as a tunable parameter — it's a
  hard Schwab limit.

## References

- Architecture: [`architecture-overview.md`](architecture-overview.md)
- Glossary: [`glossary.md`](glossary.md)
- OSI deep dive: [`osi-option-symbol.md`](osi-option-symbol.md)
