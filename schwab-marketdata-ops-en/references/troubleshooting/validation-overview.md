# Troubleshooting — Validation overview

`SchwabValidationError` is an input rejection at the **local
Pydantic layer** in the MCP server; it **does not consume** Schwab
API quota. The error always carries a `field` attribute pointing at
the offending parameter.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/validation-overview.md`](../../../schwab-marketdata-ops/references/troubleshooting/validation-overview.md).

## Routing for the 4 symptoms

| Symptom                              | Child file                                                                          |
| ------------------------------------ | ----------------------------------------------------------------------------------- |
| `field="symbol"` / `"symbols"`       | [`validation-symbol.md`](validation-symbol.md)                                       |
| price-history Cartesian product is illegal | [`validation-pricehistory-cartesian.md`](validation-pricehistory-cartesian.md)        |
| `get_quotes` exceeds 50 symbols      | [`validation-batch-50.md`](validation-batch-50.md)                                  |
| OSI option symbol format wrong        | [`validation-osi-format.md`](validation-osi-format.md)                              |

## Error shape

```text
{
  "error": "SchwabValidationError",
  "field": "symbol|symbols|period_type|period|frequency_type|frequency|cusip|projection|...",
  "message": "..."
}
```

The `field` value is the exact attribute name on the failing
Pydantic model. `message` typically references the validator output
(e.g. `"string does not match regex '^[A-Z$./ ]{1,21}$'"`).

## Decision flow

1. **Fix the input and retry once** (`aapl` → `AAPL`, split 60
   symbols into 50 + 10); only escalate if the corrected call still
   fails.
2. **Do not** treat a validation error as a server bug — 99% of the
   time it is an input parameter problem.
3. **Do not** add a second-level regex check on the agent side —
   the server already does this; the agent only needs to fix the
   parameter.

## General fix template

```python
import re

def normalize_symbol(s: str) -> str:
    s = s.strip().upper()
    if not re.fullmatch(r'[A-Z$./ ]{1,21}', s):
        raise ValueError(f"unfit symbol: {s!r}")
    return s

def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]
```

## What not to do

- **Do not** retry with the same parameters after a
  `SchwabValidationError` (it will fail again the same way).
- **Do not** file the validation error as a server bug (the vast
  majority are input issues; consult this routing table first).
- **Do not** add agent-side regex re-validation — the server has
  already done it; the agent only needs to fix the parameter and
  retry once.

## References

- Error model overview: [`../error-recovery.md`](../error-recovery.md)
- 12-tool schema: [`../tools/index.md`](../tools/index.md)
