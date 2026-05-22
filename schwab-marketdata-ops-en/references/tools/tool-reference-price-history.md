# Tool reference — Price history family

`get_price_history` — historical candles / OHLC data.

## Signature

```text
get_price_history(
    symbol: str,
    period_type: PeriodType,
    period: Period | None = None,
    frequency_type: FrequencyType,
    frequency: Frequency | None = None,
    start_datetime: datetime | None = None,
    end_datetime: datetime | None = None,
    need_extended_hours_data: bool | None = None,
    need_previous_close: bool | None = None,
)
```

## Cartesian-product legal combinations (critical constraint)

Schwab only accepts a **restricted set of combinations** for the
`(period_type, period, frequency_type, frequency)` tuple — illegal
combinations are **silently 400'd by the server**. The MCP server
pre-rejects them at the Pydantic layer to avoid wasting billed quota.

| period_type    | legal `period`                                                                            | legal `frequency_type`        | legal `frequency`                          |
| -------------- | ----------------------------------------------------------------------------------------- | ----------------------------- | ------------------------------------------ |
| `DAY`          | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `FOUR_DAYS` / `FIVE_DAYS` / `TEN_DAYS`             | `MINUTE`                       | `EVERY_MINUTE` / `EVERY_FIVE_MINUTES` / `EVERY_TEN_MINUTES` / `EVERY_FIFTEEN_MINUTES` / `EVERY_THIRTY_MINUTES` |
| `MONTH`        | `ONE_DAY` / `TWO_DAYS` / `THREE_DAYS` / `SIX_MONTHS`                                       | `DAILY` / `WEEKLY`             | (none — leave unset)                       |
| `YEAR`         | `FIFTEEN_YEARS` / `TWENTY_YEARS`                                                          | `DAILY` / `WEEKLY` / `MONTHLY` | (none)                                     |
| `YEAR_TO_DATE` | (omit)                                                                                    | `DAILY` / `WEEKLY`             | (none)                                     |

## datetime field rules

- `start_datetime` / `end_datetime` must be **timezone-aware**
  (`+00:00`, `-04:00`, etc.); naive datetimes are rejected by Pydantic.
- They cannot be in the future.
- When `start_datetime` / `end_datetime` are supplied, leave `period`
  unset — the two are mutually exclusive.

## Examples

### Today's 5-minute candles

```text
get_price_history(
    symbol="VOO",
    period_type="DAY",
    period="ONE_DAY",
    frequency_type="MINUTE",
    frequency="EVERY_FIVE_MINUTES",
)
```

### Last 6 months of daily candles

```text
get_price_history(
    symbol="VOO",
    period_type="MONTH",
    period="SIX_MONTHS",
    frequency_type="DAILY",
)
```

### Last 15 years of weekly candles

```text
get_price_history(
    symbol="VOO",
    period_type="YEAR",
    period="FIFTEEN_YEARS",
    frequency_type="WEEKLY",
)
```

### Custom start / end window

```python
from datetime import datetime, timezone

get_price_history(
    symbol="VOO",
    period_type="MONTH",
    frequency_type="DAILY",
    start_datetime=datetime(2024, 1, 1, tzinfo=timezone.utc),
    end_datetime=datetime(2024, 6, 30, tzinfo=timezone.utc),
)
```

## Return schema (excerpt)

```text
{
  "symbol": "VOO",
  "candles": [
    { "open": ..., "high": ..., "low": ..., "close": ..., "volume": ..., "datetime": <epoch_ms> },
    ...
  ],
  "empty": false,
  "previousClose": ...,            # only when need_previous_close=True
  "previousCloseDate": ...,
  "previousCloseDateISO8601": ...
}
```

`datetime` is epoch **milliseconds** (not seconds). Convert it on the
agent side with:

```python
from datetime import datetime, timezone

ts = datetime.fromtimestamp(candle["datetime"] / 1000, tz=timezone.utc)
```

## Common errors

| `error`                                                              | Cause                                                                          |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `SchwabValidationError(field="period_type"/"period"/"frequency_*")` | Illegal cartesian product (most common: `DAY` paired with `DAILY`)             |
| `SchwabValidationError(field="start_datetime"/"end_datetime")`     | Passed a naive datetime, or a datetime in the future                            |
| `candles == []` + `empty: true` with no error                       | Legal call but no data (market holiday / delisted symbol / window before listing date) |

## Quota optimization

- For long histories, prefer larger granularity (`MONTH` / `YEAR` +
  `DAILY` / `WEEKLY`); do NOT loop 200 times pulling one day at a
  time.
- `need_extended_hours_data=False` is fine as a default; only enable
  it when you specifically need pre-/after-market data.
- For time-series backfill, pull `FIFTEEN_YEARS` once and slice on
  the agent side — far cheaper on quota than repeated API calls.

## What not to do

- **Do not** pass an OSI option symbol — price history only supports
  stock / ETF / index.
- **Do not** supply both `period` and `start_datetime/end_datetime`.

## References

- Input-validation errors: [`../troubleshooting/validation-pricehistory-cartesian.md`](../troubleshooting/validation-pricehistory-cartesian.md)
- Rate limits and quota: [`../operations/rate-limit-token-bucket.md`](../operations/rate-limit-token-bucket.md)
