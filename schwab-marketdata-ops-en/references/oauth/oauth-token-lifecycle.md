# OAuth — Token lifecycle deep dive

> Consolidates the **lifetime / rotate behavior / expiry handling**
> of access_token / refresh_token / OAuth code in one place to
> simplify diagnosis.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/oauth/oauth-token-lifecycle.md`](../../../schwab-marketdata-ops/references/oauth/oauth-token-lifecycle.md).

## Lifecycle of the three tokens

```text
                ┌────────────────────┐
                │  OAuth code        │  Lifetime: 5 minutes (one-time)
                │  From browser redirect│  Rotate: N/A (one-time)
                └─────────┬──────────┘
                          │ schwab-py exchange
                          ▼
   ┌──────────────────────────┐    ┌──────────────────────────┐
   │  access_token            │    │  refresh_token           │
   │  Lifetime: 90 minutes    │    │  Lifetime: 7 days absolute  │
   │  Rotate: every refresh   │    │  Rotate: every refresh   │
   │  Use: business API auth  │    │  Use: mint a new access_token │
   └──────────────────────────┘    └──────────────────────────┘
                          │                       ▲
                          │ 90-min expiry or active call │
                          ▼                       │
                ┌────────────────────────────────┘
                │   schwab-py auto-calls the token endpoint
                │   POST refresh_token → new access_token + new refresh_token
                │   Write back to token.json
                └─────▶ Until the 7-day total lifetime is up → must re-run OAuth
```

## Key constraints

### The refresh_token has an **absolute** 7-day lifetime

- Whether you use it or not, the server invalidates it 7 days after
  **first issuance**.
- This is a **hard limit** of Schwab OAuth and cannot be extended by
  any client implementation.
- For automation, a **human** must re-run `auth login_flow` (or
  `manual_flow`) every 7 days.

### Rotate-on-use

Every refresh issues a **new** refresh_token that replaces the old
one:

| Time    | State                                                                            |
| ------- | -------------------------------------------------------------------------------- |
| t=0     | OAuth complete; token.json contains RT₁ (valid 7 days, until t=7d) and AT₁ (90 min, until t=90m) |
| t=80m   | schwab-py refreshes before the next business call → writes RT₂ (still 7d expiry at t=7d, **not extended**) and AT₂ |
| t=7d    | Any RT generation expires; the next business call raises `SchwabAuthError(reason="refresh_token_expired")` |
| Recovery | The user runs `auth login_flow` → new RT issued, t' resets to 0                   |

Note that RT₂ does not extend the 7-day total lifetime. The countdown
starts from your **first** OAuth, not from each refresh.

### Can you copy token.json across machines?

**No**:

1. rotate-on-use: once machine A refreshes, machine B's RT is
   invalidated immediately.
2. Schwab does not advertise a strict token-IP binding, but
   empirically multi-machine concurrent use of the same token gets
   throttled / temporarily suspended.

Correct approach: run OAuth once per machine, and once per account.

### Pre-expiry warning

The `schwab_marketdata_mcp.health` module ships a built-in **desktop
notification** mechanism:

- When `token_expires_in_days < 12h` and the token is not `valid` →
  drop a `~/Desktop/SCHWAB_REAUTH_NEEDED.md` marker and trigger an
  OS notification (macOS: notification center; Linux: notify-send
  critical).
- Combined with cron / launchd (every 4h + Sunday 20:00 +
  Wednesday 21:00), the user gets ≥ 12h advance warning to
  reauthorize.

See [Quick Start Step 7](../quick-start/step-7-cron-launchd-setup.md).

## token.json fields

```json
{
  "creation_timestamp": 1716200000,
  "token": {
    "access_token": "...",            // 90 minutes
    "refresh_token": "...",           // 7 days
    "id_token": "...",                // schwab-py 1.5+
    "token_type": "Bearer",
    "expires_in": 1800,
    "expires_at": 1716201800,
    "scope": "api"
  }
}
```

`creation_timestamp` is a field schwab-py writes itself; the
`health` module uses it to compute `token_age_days`.

## Health-check model

```text
                 ┌────────────────────────────────────┐
                 │         health_check()             │
                 └────────┬───────────────────────────┘
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        token_state   token_age_days  token_expires_in_days
        (4-enum)      (since creation) (until 7-day expiry)
              │           │           │
              ▼           ▼           ▼
        ┌────────────────────────────┐
        │   Decision table           │
        │   See troubleshooting/     │
        │   auth-token-states.md     │
        └────────────────────────────┘
```

## Will repeated refreshes within the 7-day window be throttled?

Empirically a refresh every 90 minutes (schwab-py's default
behavior) is not throttled. But if you **manually** force a refresh
every minute, the Schwab token endpoint will throttle (typically
1 req / 60s).

The agent **should not** trigger refreshes manually — schwab-py
already checks expiry before every business call.

## FAQ

### Q: Can I use `id_token` as a long-lived credential?

No. `id_token` is an identity assertion (OIDC) only; it cannot be
exchanged for an access_token and cannot call the business API.

### Q: If I delete token.json, will my old RT be invalidated by Schwab immediately?

No. The server invalidates an RT only when: (1) 7 days have
elapsed, (2) you **Reset App Secret** in the Developer Portal, or
(3) Schwab's internal anomaly detection revokes it. Deleting the
local token.json only loses local state.

### Q: Can I refresh tokens with something other than schwab-py?

Technically yes (standard OAuth refresh_token grant + Basic Auth
with App Key / Secret), but you'd have to implement rotate-on-use
write-back and concurrency safety yourself. Strongly recommended to
stick with schwab-py.

## References

- TokenState 4-state explainer: [`../troubleshooting/auth-token-states.md`](../troubleshooting/auth-token-states.md)
- refresh_token expiry handling: [`../troubleshooting/auth-refresh-expired.md`](../troubleshooting/auth-refresh-expired.md)
- Health-check automation: [`../quick-start/step-7-cron-launchd-setup.md`](../quick-start/step-7-cron-launchd-setup.md)
