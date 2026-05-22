# Architecture overview

> All key components, data flows, and trust boundaries of
> `schwab-marketdata-mcp` collected in one place.

## Component overview

```text
┌────────────────────┐
│   AI agent         │  Cursor / Claude / Kiro / custom SDK clients
│   (skills here)    │
└────────┬───────────┘
         │ MCP JSON-RPC over stdio
         ▼
┌──────────────────────────────────────────────────────────┐
│   schwab-marketdata-mcp (this repo)                      │
│                                                          │
│   ┌──────────────┐   ┌──────────────┐   ┌─────────────┐  │
│   │ Pydantic     │ → │ token-bucket │ → │ schwab-py   │  │
│   │ validation   │   │ (rate limit) │   │ client      │  │
│   │ (model.py)   │   │              │   │             │  │
│   └──────────────┘   └──────────────┘   └─────────────┘  │
│                                                  │       │
│   ┌──────────────────────────┐                   │       │
│   │ token persister          │ ◀─── access_token┘       │
│   │ (~/.local/state/...)     │     refresh on each call │
│   └──────────────────────────┘                          │
└──────────────────────────────────────────┬───────────────┘
                                           │ HTTPS / OAuth Bearer
                                           ▼
                              ┌────────────────────────┐
                              │ Schwab Market Data API │
                              │ (api.schwabapi.com)    │
                              └────────────────────────┘
```

## The 5 core components

| Component | File | Responsibility |
| --------- | ---- | -------------- |
| **Tools** | `src/schwab_marketdata_mcp/tools/` | 12 outward-facing async functions; each tool defines its input schema with a Pydantic model |
| **Models** | `src/schwab_marketdata_mcp/models.py` | All Pydantic Literal enum definitions; provides bidirectional translation between enum names and schwab-py wire values |
| **Errors** | `src/schwab_marketdata_mcp/errors.py` | The 4 `SchwabXError` classes: `Auth` / `RateLimit` / `Validation` / `Transient` |
| **Auth** | `src/schwab_marketdata_mcp/auth.py` + `auth_logic.py` | OAuth `login_flow` / `manual_flow` CLI; token persister; permission self-check |
| **Health** | `src/schwab_marketdata_mcp/health.py` | Standalone executable module; returns health JSON; triggers desktop notifications |

Helper components:

- `client.py`: a thin wrapper around the schwab-py async client,
  injecting the token bucket.
- `security.py`: token-path allow-list, cloud-sync detection,
  enforced `chmod`.
- `metrics.py`: structured stderr logging, `recent_error_count_24h`
  counter.
- `stats.py`: token-bucket implementation.

## Data flow: a single `get_quote` call

```text
agent.call_tool("get_quote", {"symbol": "AAPL"})
  │
  ▼
[1] MCP server receives JSON-RPC tools/call
  │
  ▼
[2] tools/quotes.py: get_quote(symbol="AAPL")
  │
  ▼
[3] Pydantic validates symbol (UPPERCASE regex)
  │  fail → return SchwabValidationError dict immediately (no quota consumed)
  ▼
[4] token-bucket checks for an available slot
  │  0 slots → return SchwabRateLimitError immediately (does not block)
  ▼
[5] schwab-py.get_quote(symbol)
  │  internally checks access_token lifetime → refresh if necessary
  │  refresh fails (7-day expiry) → SchwabAuthError
  ▼
[6] HTTP GET https://api.schwabapi.com/marketdata/v1/AAPL/quotes
  │  Authorization: Bearer <access_token>
  │  Schwab returns 200 / 401 / 429 / 4xx / 5xx
  ▼
[7] schwab-py parses the response / handles Retry-After / retries
  │  non-200 → translated into the corresponding SchwabXError
  ▼
[8] tool function returns a dict (with or without an `error` field)
  │
  ▼
[9] MCP server serializes the dict into result.content[0].text
  │
  ▼
agent receives a JSON string
```

## Trust boundaries

| Boundary | Data | Control point |
| -------- | ---- | ------------- |
| Agent ↔ MCP server | symbol, enum, callback parameters | Pydantic rejects illegal input |
| MCP server ↔ Schwab | Bearer access_token | schwab-py auto-injects + auto-refreshes |
| MCP server ↔ token.json | refresh_token | OS file permissions (600/700) + allow-list paths |
| MCP server ↔ stderr | log lines | metrics.py masks `Bearer ...` globally |
| Skills ↔ Agent | language directive, version-handshake directive | language_directive + compatible_mcp_version |

## Outbound HTTP headers

Headers sent on every `api.schwabapi.com` request, sorted by
sensitivity:

| Header | Source | Meaning |
| ------ | ------ | ------- |
| `Authorization: Bearer <access_token>` | schwab-py auto-injects; access_token comes from token.json | OAuth auth; auto-refreshes 5 minutes before expiry |
| `User-Agent: schwab-marketdata-mcp/<ver> python/<ver> schwab-py/<ver>` | `client._inject_user_agent` writes into `client.session.headers` | Basis for Schwab Developer Portal **Device Type** classification; without this it falls into `Unknown` |
| `Accept: application/json` | httpx default + schwab-py explicit | Response-format negotiation |
| `Host: api.schwabapi.com` | httpx automatic | TLS SNI / routing |

The User-Agent intentionally carries only package versions, **not**
username, hostname, or PII; if a future schwab-py removes or renames
`session.headers`, the injection helper falls back silently to the
httpx default UA (the data path is not interrupted).

## Error normalization

All Schwab failures are normalized into `{"error": "Schwab*Error", ...}`
dicts, **not propagated as exceptions** through the MCP protocol. This
ensures the agent always receives structured data and can route by
type. See [`error-recovery.md`](../error-recovery.md).

## Quota and rate limiting

- **Local**: token bucket, default 120 req/min, configurable in
  `.env`. The slot is released during retry sleep (the key difference
  vs. `asyncio.Semaphore`).
- **Server-side**: Schwab does not publish exact numbers; community
  estimates are around 120 req/min/user.
- **Local first**: keep the local limit stricter than the server's,
  to avoid being recorded by Schwab (sustained over-limit triggers
  stricter server-side blocks).

See [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md).

## Multi-machine / multi-account

- `token.json` is **machine-local state**; refresh_token is
  rotate-on-use and cannot be shared across machines.
- Multi-machine same account → run OAuth once per machine.
- Multi-account → use `--config-dir` to specify different token paths
  and manage each account separately.

## What not to do

- **Do not** call `schwab-py` directly from code outside the server
  process (your own Python script) — that bypasses the token bucket
  and error normalization.
- **Do not** assume independence in multi-agent concurrency — the
  token bucket is shared at the server-process level; minute quota is
  the sum across all agents.
- **Do not** raise the `errors.py` exception classes back out — the
  server already converts them to returned dicts; if you fork the
  code, preserve that contract.

## References

- 12-tool index: [`../tools/index.md`](../tools/index.md)
- OAuth flow: [`../oauth/oauth-overview.md`](../oauth/oauth-overview.md)
- Rate-limit deep dive: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
- Glossary: [`glossary.md`](glossary.md)
