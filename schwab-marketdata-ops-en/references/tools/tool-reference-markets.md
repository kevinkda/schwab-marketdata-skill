# Tool reference — Markets family

`get_market_hours` / `get_market_hour_single` — market open/close
status.

## 1. `get_market_hours(markets_list, date?)`

Query open/close status for 1-5 markets at once.

| Param         | Type / values                                                                  |
| ------------- | ------------------------------------------------------------------------------ |
| markets_list  | `list[MarketEnum]`: 1-5 of `{"EQUITY", "OPTION", "BOND", "FUTURE", "FOREX"}`    |
| date          | TZ-aware datetime / date; not more than 30 days in the future; default = today |

### Examples

```text
get_market_hours(markets_list=["EQUITY", "OPTION"])
get_market_hours(markets_list=["EQUITY"], date=datetime(2024, 4, 19, tzinfo=timezone.utc))
```

### Return schema (excerpt)

```text
{
  "equity": {
    "EQ": {
      "date": "2024-04-19",
      "marketType": "EQUITY",
      "exchange": "NULL",
      "category": "EQ",
      "product": "EQ",
      "productName": "equity",
      "isOpen": true,
      "sessionHours": {
        "preMarket": [ { "start": "2024-04-19T07:00:00-04:00", "end": "2024-04-19T09:30:00-04:00" } ],
        "regularMarket": [ { "start": "2024-04-19T09:30:00-04:00", "end": "2024-04-19T16:00:00-04:00" } ],
        "postMarket": [ { "start": "2024-04-19T16:00:00-04:00", "end": "2024-04-19T20:00:00-04:00" } ]
      }
    }
  },
  "option": { ... }
}
```

## 2. `get_market_hour_single(market_id, date?)`

Query a single market only.

| Param      | Type / values                                                  |
| ---------- | -------------------------------------------------------------- |
| market_id  | `"EQUITY"` / `"OPTION"` / `"BOND"` / `"FUTURE"` / `"FOREX"`     |
| date       | same as above                                                  |

### Examples

```text
get_market_hour_single(market_id="EQUITY")
get_market_hour_single(market_id="BOND", date=datetime(2024, 7, 4, tzinfo=timezone.utc))
```

## When to use which?

| Scenario                        | Use                          |
| ------------------------------- | ---------------------------- |
| Inspecting only 1 market         | `get_market_hour_single`    |
| Inspecting ≥ 2 markets at once   | `get_market_hours`          |
| Only need the `isOpen` boolean   | Either; the structure is the same |
| Scheduled bulk weekend job       | Cache the day's result (30 min TTL is enough); do not call repeatedly |

## Timezone notes

- `sessionHours` `start` / `end` are timezone-aware ISO 8601 (usually
  `-04:00` / `-05:00`); the agent must not assume UTC.
- `date` accepts a datetime or a date, but the server normalizes
  internally to the local market date. Passing
  `2024-04-19T22:00:00+00:00` (i.e. 22:00 UTC) is treated as 18:00
  US-Eastern, which still falls inside the 4/19 trading day.

## Holiday handling

`isOpen == false` does not distinguish **weekend** / **holiday** /
**early close**. To tell them apart, check whether `sessionHours` is
fully empty (holiday) or whether `regularMarket` ends early (early
close — common on Black Friday and Christmas Eve).

## Common errors

| `error`                                            | Cause                                                       |
| -------------------------------------------------- | ----------------------------------------------------------- |
| `SchwabValidationError(field="markets_list")`     | Length 0 or > 5; contains an enum value not in the list      |
| `SchwabValidationError(field="date")`              | naive datetime; more than current date + 30 days              |
| `equity.EQ.isOpen` field missing                   | Rare, usually upstream cache jitter; retry after 30 seconds |

## What not to do

- **Do not** call `get_market_hours` in a tight loop in a playbook
  (high-frequency metadata) — the agent should keep an in-memory
  cache; 30s TTL is enough.
- **Do not** use this tool for real-time market open/close monitoring
  (the data is per-day, not streaming).

## References

- Rate-limit-warning handling: [`../troubleshooting/rate-limit-warning-stderr.md`](../troubleshooting/rate-limit-warning-stderr.md)
- Caching strategy: [`../operations/observability-and-caching.md`](../operations/observability-and-caching.md)
