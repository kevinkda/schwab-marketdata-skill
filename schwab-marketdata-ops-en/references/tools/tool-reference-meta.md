# Tool reference — Meta family

`health_check` / `get_server_info` — health probes and version
handshake. **Does not consume Schwab quota** (only local state reads
and optional token metadata validation).

## 1. `health_check()`

No parameters; returns a snapshot of the current server health.

### Return schema

```text
{
  "server_version": "0.1.x",
  "token_state": "valid" | "missing" | "malformed" | "insecure_perms",
  "token_age_days": float | null,
  "token_expires_in_days": float | null,
  "last_request_status": "unknown" | "ok" | "error",
  "rate_limit_remaining_per_min": int,
  "recent_error_count_24h": int,
  "platform_supported": true
}
```

### Field semantics

| Field                            | Meaning                                                                  |
| -------------------------------- | ------------------------------------------------------------------------ |
| `server_version`                 | Current MCP server version (used to compare against `compatible_mcp_version`) |
| `token_state`                    | One of `valid` / `missing` / `malformed` / `insecure_perms` (see below)  |
| `token_age_days`                 | Days since the token was created (refreshed on each refresh)             |
| `token_expires_in_days`          | Days until refresh_token expiry; < 0.5 strongly suggests immediate reauthorize |
| `last_request_status`            | Result of the most recent business call (`ok` / `error` / `unknown`)     |
| `rate_limit_remaining_per_min`   | Currently available slots in the local token bucket (default capacity 120) |
| `recent_error_count_24h`         | Count of `Schwab*Error` instances in the last 24 hours (all types)       |
| `platform_supported`             | Whether the OS is supported (true only for macOS 11+ / Linux)            |

### Remediation for the 4 `token_state` values

| Value             | Remediation                                                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------- |
| `valid`           | ✅ Everything OK; continue with business calls                                                  |
| `missing`         | `token.json` does not exist; run `auth login_flow` to initialize                              |
| `malformed`       | JSON corrupt / fields missing; back up and re-run OAuth                                        |
| `insecure_perms`  | Mode is not `600` / `700`; run `chmod 600 token.json` and `chmod 700 $(dirname token.json)`   |

The full mapping table lives in [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md).

### Example

```text
health_check()
```

### When to call

- **Right after every skill activation**: first `get_server_info`
  (version handshake), then `health_check` (token check-up).
- **At the start of every playbook**: as part of pre-flight.
- **When a `SchwabAuthError` is observed**: first run health to see
  `token_state`, then decide whether to reauthorize.
- **cron / launchd probes**: automated health probes (see Quick Start
  Step 7).

## 2. `get_server_info()`

No parameters; returns server metadata. **Independent of token state**
(callable even when the token is invalid).

### Return schema

```text
{
  "server_version": "0.1.x",
  "mcp_sdk_version": "1.x.x",
  "schwab_py_version": "1.5.1",
  "supported_tools": [
    "get_quote",
    "get_quotes",
    "get_price_history",
    "get_option_chain",
    "get_option_expiration_chain",
    "get_market_hours",
    "get_market_hour_single",
    "get_movers",
    "search_instruments",
    "get_instrument_by_cusip",
    "health_check",
    "get_server_info"
  ],
  "platform_supported_v1": ["macos>=11", "linux"]
}
```

### Field semantics

| Field                       | Meaning                                                                  |
| --------------------------- | ------------------------------------------------------------------------ |
| `server_version`            | Used for skill `compatible_mcp_version` range matching                   |
| `mcp_sdk_version`           | Current MCP Python SDK version                                           |
| `schwab_py_version`         | Current schwab-py version                                                |
| `supported_tools`           | The 12 tool string names (agents can use it for capability discovery)    |
| `platform_supported_v1`     | List of supported OSes for v0.1                                          |

### When to call

- **The first time the skill activates**: must be called once for
  version handshake. If `server_version` falls outside the
  `compatible_mcp_version` range, **stop immediately** and tell the
  user to upgrade the server or the skill.
- **The first time you register with a new client**: confirms all 12
  tools are correctly exposed.

## When to use which?

| Scenario                                       | Use                  |
| ---------------------------------------------- | -------------------- |
| First skill activation step (version handshake) | `get_server_info`   |
| Token state check-up                            | `health_check`      |
| Debugging whether a specific call connected    | Call both once       |
| cron / launchd automated probe                 | `health_check` (sufficient) |
| Capability discovery (list all tools)          | `get_server_info`   |

## What not to do

- **Do not** use `health_check` as a keepalive (frequency should be ≥
  4h; anything more frequent is pointless).
- **Do not** treat `get_server_info` as a health check — it does not
  read token state.
- **Do not** dump full `health_check` output into error logs — it
  contains metadata like `token_age_days` from which usage patterns
  can be inferred; mask first.

## References

- Token lifecycle: [`../oauth/oauth-token-lifecycle.md`](../oauth/oauth-token-lifecycle.md)
- TokenState deep dive: [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
- Health probe automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
