# Troubleshooting — Price history Cartesian product invalid

`get_price_history`'s
`(period_type, period, frequency_type, frequency)` 4-tuple only
accepts a **restricted set of combinations**; illegal combinations
**silently 400** at the Schwab server. The MCP server intercepts at
the Pydantic layer.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/validation-pricehistory-cartesian.md`](../../../schwab-marketdata-ops/references/troubleshooting/validation-pricehistory-cartesian.md).

## Symptom

```text
{"error":"SchwabValidationError","field":"period_type|period|frequency_type|frequency","message":"..."}
```

`field` is normally the first parameter where the conflict was
detected; `message` carries the Pydantic explanation (e.g.
`"frequency_type DAILY is not allowed when period_type=DAY"`).

## Root cause (3 typical patterns)

1. **`DAY` paired with `DAILY`** — `period_type="DAY"` only allows
   `frequency_type="MINUTE"`
2. **`MONTH` with a `frequency` value** — when `period_type="MONTH"`,
   `frequency` must be left unset
3. **`YEAR_TO_DATE` with a `period` value** — when
   `period_type="YEAR_TO_DATE"`, `period` must be left unset

## Complete legal-combination table

| period_type    | legal `period`                                                          | legal `frequency_type`        | legal `frequency`        |
| -------------- | ----------------------------------------------------------------------- | ----------------------------- | ------------------------ |
| `DAY`          | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `FOUR_DAYS` / `FIVE_DAYS` / `TEN_DAYS` | `MINUTE`                       | `EVERY_MINUTE` / `EVERY_FIVE_MINUTES` / `EVERY_TEN_MINUTES` / `EVERY_FIFTEEN_MINUTES` / `EVERY_THIRTY_MINUTES` |
| `MONTH`        | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `SIX_MONTHS`                     | `DAILY` / `WEEKLY`             | (none — leave unset)     |
| `YEAR`         | `FIFTEEN_YEARS` / `TWENTY_YEARS`                                        | `DAILY` / `WEEKLY` / `MONTHLY` | (none)                    |
| `YEAR_TO_DATE` | (omit)                                                                  | `DAILY` / `WEEKLY`             | (none)                    |

## Fix template

```python
# Pull 1 year of daily candles, written wrong:
get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                  frequency_type="DAILY")  # error
# 6 months of daily candles:
get_price_history(symbol="VOO", period_type="MONTH", period="SIX_MONTHS",
                  frequency_type="DAILY")
# Today's minute candles:
get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                  frequency_type="MINUTE", frequency="EVERY_FIVE_MINUTES")
# Year-to-date daily candles:
get_price_history(symbol="VOO", period_type="YEAR_TO_DATE",
                  frequency_type="DAILY")
```

## Use start/end datetime in lieu of period

```python
from datetime import datetime, timezone

# Custom range (period must be left unset; the two are mutually exclusive)
get_price_history(
    symbol="VOO",
    period_type="MONTH",
    frequency_type="DAILY",
    start_datetime=datetime(2024, 1, 1, tzinfo=timezone.utc),
    end_datetime=datetime(2024, 6, 30, tzinfo=timezone.utc),
)
```

Notes:

- `start_datetime` / `end_datetime` must be **timezone-aware**
- Neither may be in the future
- Passing `period` together with `start_datetime/end_datetime` is
  rejected by Pydantic

## Verification

```python
result = await get_price_history(...)
assert result.get("error") is None
assert "candles" in result
assert len(result["candles"]) > 0
```

## 4-step illegal-combination checklist

```python
def check_pricehistory_args(period_type, period, frequency_type, frequency):
    rules = {
        "DAY":          ("MINUTE", True),     # frequency required
        "MONTH":        (("DAILY","WEEKLY"), False),
        "YEAR":         (("DAILY","WEEKLY","MONTHLY"), False),
        "YEAR_TO_DATE": (("DAILY","WEEKLY"), False),
    }
    if period_type not in rules:
        return f"unknown period_type: {period_type}"
    legal_ft, freq_required = rules[period_type]
    if isinstance(legal_ft, str):
        legal_ft = (legal_ft,)
    if frequency_type not in legal_ft:
        return f"frequency_type {frequency_type} not allowed for period_type {period_type}"
    if freq_required and frequency is None:
        return f"frequency required for period_type {period_type}"
    if not freq_required and frequency is not None:
        return f"frequency must be unset for period_type {period_type}"
    return None
```

## What not to do

- **Do not** combine `period` with `start_datetime/end_datetime`
  (mutually exclusive).
- **Do not** pass naive datetimes (must be TZ-aware).
- **Do not** confuse `period` with `frequency` — `period` is the
  lookback window length, `frequency` is the granularity per
  candle.

## References

- Price history tool reference: [`../tools/tool-reference-price-history.md`](../tools/tool-reference-price-history.md)
- Validation overview: [`validation-overview.md`](validation-overview.md)
