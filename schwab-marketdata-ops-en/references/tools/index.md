# Tool reference — index

> All 13 outward-facing tools are `async`.  All inputs are validated by
> Pydantic before any network call.  All outputs are JSON dicts.  Errors
> are returned **as dicts** (`{"error": "Schwab…Error", …}`) — they are
> *not* raised back through the MCP protocol.

Split by tool family for easy scenario-based lookup:

| Family | File | Tools | When to read |
| ------ | ---- | ----- | ------------ |
| Quotes | [`tool-reference-quotes.md`](tool-reference-quotes.md) | `get_quote` / `get_quotes` | Single-symbol or batched quotes |
| Price history | [`tool-reference-price-history.md`](tool-reference-price-history.md) | `get_price_history` | OHLC / candles, need to look up the legal cartesian-product combinations |
| Options | [`tool-reference-options.md`](tool-reference-options.md) | `get_option_chain` / `get_option_expiration_chain` | Option chains, expiration lists |
| Markets | [`tool-reference-markets.md`](tool-reference-markets.md) | `get_market_hours` / `get_market_hour_single` | Multi-market or single-market open/close status |
| Movers | [`tool-reference-movers.md`](tool-reference-movers.md) | `get_movers` | Today's top movers |
| Instruments | [`tool-reference-instruments.md`](tool-reference-instruments.md) | `search_instruments` / `get_instrument_by_cusip` | Fuzzy lookup or exact CUSIP lookup |
| Meta | [`tool-reference-meta.md`](tool-reference-meta.md) | `health_check` / `get_server_info` | Health probe and version handshake |
| Streaming 🧪 | [`tool-reference-streaming.md`](tool-reference-streaming.md) | `get_streaming_snapshot` | Near-real-time bid/ask/last or 1-minute candles (experimental) |

## Cross-tool conventions

1. **symbol case**: every tool's `symbol` / `symbols` argument must be
   UPPERCASE.  Passing `"aapl"` is rejected immediately by Pydantic
   with `SchwabValidationError(field="symbol")`.
2. **enums must use names**: for example, `MoversIndex.DJI` = `"DJI"`,
   not `"$DJI"`. The MCP server translates internally to the
   schwab-py wire value.
3. **batch limit of 50**: `get_quotes` / `search_instruments` accept
   at most 50 symbols per call; exceeding the limit is rejected
   immediately by Pydantic.
4. **TZ-aware datetime**: every time argument (`from_date` /
   `to_date` / `start_datetime` / `end_datetime` / `date`) must carry
   timezone info (`+00:00`, `-04:00`, etc.) and must not be in the
   future.
5. **errors are dicts**: every failing tool **returns**
   `{"error": "...", ...}` instead of raising through the MCP
   protocol. Always check the `error` field before reading the
   payload.
6. **stdout contains no secrets**: the MCP server's global filter
   masks any `Bearer ...` / `Authorization` headers; the agent should
   also mask defensively.

## What not to do

- **Do not** re-validate symbols with regex on the agent side — the
  server already does that.
- **Do not** pass enum wire values (`"$DJI"`, `"day"`) directly.
- **Do not** pass an OSI option symbol to `get_option_chain` — OSI is
  only for `get_quote` / `get_quotes`.

## Further reading

- Error triage: [`../error-recovery.md`](../error-recovery.md)
- Input-validation remediation: [`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
- Rate-limit handling: [`../troubleshooting/rate-limit-overview.md`](../troubleshooting/rate-limit-overview.md)
