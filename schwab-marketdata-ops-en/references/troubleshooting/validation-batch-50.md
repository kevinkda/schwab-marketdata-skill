# Troubleshooting — `get_quotes` exceeded 50 symbols

`get_quotes` / `search_instruments` accepts at most 50 symbols per
call. Exceeding the limit is rejected immediately by Pydantic.

## Source

For the original Chinese version, see
[`../../../schwab-marketdata-ops/references/troubleshooting/validation-batch-50.md`](../../../schwab-marketdata-ops/references/troubleshooting/validation-batch-50.md).

## Symptom

```text
{"error":"SchwabValidationError","field":"symbols","message":"max length 50"}
```

## Root cause

The Schwab hard cap is 50 / call; the server-side Pydantic
`max_length=50` enforces it.

## Diagnostic command

```python
print(len(symbols))   # must be ≤ 50
```

## Remediation strategy

Chunk yourself:

```python
def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

results = {}
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch, fields=["QUOTE"])
    results.update(page)
```

TypeScript equivalent:

```typescript
function* chunked<T>(arr: T[], n = 50): Generator<T[]> {
    for (let i = 0; i < arr.length; i += n) {
        yield arr.slice(i, i + n);
    }
}

const results: Record<string, unknown> = {};
for (const batch of chunked(symbols, 50)) {
    const page = await c.call("get_quotes", { symbols: batch, fields: ["QUOTE"] });
    Object.assign(results, page);
}
```

## Rate-limit note

Each `get_quotes(50)` consumes **1 token-bucket slot**. With 1,000
symbols you split into 20 batches and consume 20 slots; under the
~120/min quota that's well within budget.

But **do not** dispatch the 20 batches concurrently with
`asyncio.gather` (it bursts the bucket; see
[`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)).
Recommended: serialize at ~0.5s spacing.

## Verification

```python
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch)
    assert "error" not in page or page["error"] is None
```

## What not to do

- **Do not** patch `max_length` to 100 in a fork — Schwab's server
  will reject first.
- **Do not** comma-join 50 symbols into a single string —
  `symbols` is a list type.

## References

- Quotes tool reference: [`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md)
- Rate-limit handling: [`rate-limit-overview.md`](rate-limit-overview.md)
- Validation overview: [`validation-overview.md`](validation-overview.md)
