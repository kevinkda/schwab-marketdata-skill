# Troubleshooting — `SchwabTransientError`

A Schwab server-side 5xx / network jitter; schwab-py has already
retried with exponential backoff `SCHWAB_MAX_RETRIES` (default 2)
times without success.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/transient-errors.md`](../../../schwab-marketdata-ops/references/troubleshooting/transient-errors.md).

## Symptom

```text
{
  "error": "SchwabTransientError",
  "status_code": <5xx, or a 4xx other than 401/429>,
  "message": "..."
}
```

## Root cause

| Category                      | Meaning                                                                              |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| **5xx (500/502/503/504)**     | Schwab server-side fault / gateway timeout; schwab-py already retried `SCHWAB_MAX_RETRIES` times with exponential backoff |
| **4xx other than 401/429 (400/404)** | Usually edge-case input that Pydantic did not catch (a field where the Schwab server is stricter than the docs suggest) |

## Remediation strategy

### 5xx: wait and observe

- Wait 30–60 seconds, then **retry once**
- If you see ≥ 3 occurrences in 30 minutes → tell the user Schwab
  may be having an outage
- Check the [Schwab Developer Portal Status](https://developer.schwab.com/) page

```python
import asyncio

async def call_with_5xx_retry(call, max_attempts=3):
    for attempt in range(max_attempts):
        result = await call()
        if result.get("error") != "SchwabTransientError":
            return result
        if result.get("status_code", 0) < 500:
            return result   # 4xx — do not retry, it's a parameter problem
        await asyncio.sleep(30 * (attempt + 1))
    return result
```

### 4xx other than 401/429

- Cross-check parameters against [`validation-overview.md`](validation-overview.md)
  and the 12-tool reference
- Try the `--dry-run` mode (partially supported by schwab-py)
- Still stuck → file an issue against `schwab-marketdata-mcp` (attach
  stderr log + call args; mask any token / Bearer first)

## Diagnostic command

```bash
# Check the schwab-py error in server.log
tail -50 ~/.local/state/schwab-marketdata-mcp/logs/server.log \
    | grep -E "(status_code|SchwabTransientError)"
```

## Verification

```bash
# Wait several minutes and check that error counts are stable
sleep 300
uv run python -m schwab_marketdata_mcp.health \
    | jq '.recent_error_count_24h'
```

≥ 1 success out of 3 retries = transient jitter; sustained failure
= real outage.

## Distinguishing real outage from transient jitter

| Dimension                   | Transient jitter      | Real outage                     |
| --------------------------- | --------------------- | ------------------------------- |
| Retries within 5 minutes    | 1–2                   | ≥ 3                             |
| Error spacing               | Sporadic              | Persistent ≥ 1/min              |
| Total business calls vs error count | Error rate < 1%        | Error rate > 5%                 |
| Affects all tools or just one | Usually one          | Usually all                     |
| Schwab status-page notice   | None                  | Usually yes                     |

## What not to do

- **Do not** retry indefinitely on 5xx — at least 30s between
  attempts, max 3 attempts.
- **Do not** treat 4xx as transient (4xx is a parameter problem and
  will not self-heal).
- **Do not** bypass `SCHWAB_MAX_RETRIES` with your own agent-side
  retry — server-side and agent-side retries stack, and the
  exponential wait blows up.

## References

- Error model overview: [`../error-recovery.md`](../error-recovery.md)
- Validation errors: [`validation-overview.md`](validation-overview.md)
- Schwab status page: <https://developer.schwab.com/>
