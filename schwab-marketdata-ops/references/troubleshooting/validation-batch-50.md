# Troubleshooting — `get_quotes` exceeded 50 symbols

`get_quotes` / `search_instruments` 单次最多 50 个 symbol。超过会立即被
Pydantic 拦下。

## Symptom

```text
{"error":"SchwabValidationError","field":"symbols","message":"max length 50"}
```

## Root cause

Schwab 硬上限是 50 / 调用，server 端 Pydantic `max_length=50` 拦截。

## 检查命令

```python
print(len(symbols))   # 必须 ≤ 50
```

## 修复策略

自行分批：

```python
def chunked(lst, n=50):
    for i in range(0, len(lst), n):
        yield lst[i:i+n]

results = {}
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch, fields=["QUOTE"])
    results.update(page)
```

TypeScript 等价：

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

## 限流注意

每次 `get_quotes(50)` 算 **1 个 token-bucket slot**。如果你有 1000 个
symbol，分 20 批，吃 20 slot；按 ~120/min 配额，仍很从容。

但**不要**用 `asyncio.gather` 把 20 批并发发出去（会瞬时打满
bucket，详见 [`rate-limit-token-bucket-empty.md`](rate-limit-token-bucket-empty.md)）。
建议按 0.5s 间隔串行。

## 验证

```python
for batch in chunked(symbols, 50):
    page = await get_quotes(symbols=batch)
    assert "error" not in page or page["error"] is None
```

## 不要做的事

- **不要** 试图把 `max_length` 在 fork 里改成 100 —— Schwab 服务端会先
  发飙。
- **不要** 把 50 个 symbol 用逗号拼成一个字符串传 —— `symbols` 是
  list 类型。

## 参考

- Quotes tool reference：[`../tools/tool-reference-quotes.md`](../tools/tool-reference-quotes.md)
- 限流处置：[`rate-limit-overview.md`](rate-limit-overview.md)
- Validation overview：[`validation-overview.md`](validation-overview.md)
