# Tool reference — Instruments family

`search_instruments` / `get_instrument_by_cusip` — 模糊查找与精确查找。

## 1. `search_instruments(symbols, projection)`

按 ticker 或描述模糊查找 instrument 元数据。

| Param      | Type / values                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| symbols    | `list[str]`，长度 1-50                                                                                       |
| projection | `SYMBOL_SEARCH` / `SYMBOL_REGEX` / `DESCRIPTION_SEARCH` / `DESCRIPTION_REGEX` / `SEARCH` / `FUNDAMENTAL`     |

### projection 选哪个？

| 用户意图                                 | 用                       |
| ---------------------------------------- | ------------------------ |
| 精确 ticker → 元数据                     | `SYMBOL_SEARCH`          |
| 字符串通配 ticker（含 `*` `?`）           | `SYMBOL_REGEX`           |
| 公司名 substring 查找                     | `DESCRIPTION_SEARCH`     |
| 公司名正则查找                           | `DESCRIPTION_REGEX`      |
| 综合查找（字符或描述都试）                | `SEARCH`                 |
| 想要详细基本面字段（财报、市值等）         | `FUNDAMENTAL`            |

### 调用示例

```text
# 精确查 AAPL 元数据
search_instruments(symbols=["AAPL"], projection="SYMBOL_SEARCH")

# 通配查所有 BRK.* （把 . 当字面量；要正则用 SYMBOL_REGEX）
search_instruments(symbols=["BRK*"], projection="SYMBOL_REGEX")

# 模糊查公司名含 "tesla"
search_instruments(symbols=["TESLA"], projection="DESCRIPTION_SEARCH")

# 拉 AAPL 详细基本面
search_instruments(symbols=["AAPL"], projection="FUNDAMENTAL")
```

### 返回 schema（节选）

```text
{
  "instruments": [
    {
      "cusip": "037833100",
      "symbol": "AAPL",
      "description": "APPLE INC",
      "exchange": "NASDAQ",
      "assetType": "EQUITY",
      "fundamental": {                     # 仅 projection="FUNDAMENTAL" 时
        "high52": ...,
        "low52": ...,
        "dividendAmount": ...,
        "peRatio": ...,
        ...
      }
    },
    ...
  ]
}
```

## 2. `get_instrument_by_cusip(cusip)`

按 9 位 CUSIP 精确查找单个 instrument。

| Param  | Type                                |
| ------ | ----------------------------------- |
| cusip  | exactly 9 alphanumeric characters   |

### 调用示例

```text
get_instrument_by_cusip(cusip="037833100")   # AAPL
```

### 返回 schema（节选）

```text
{
  "instruments": [
    {
      "cusip": "037833100",
      "symbol": "AAPL",
      "description": "APPLE INC",
      ...
    }
  ]
}
```

## 何时用哪一个？

| 场景                                  | 用                          |
| ------------------------------------- | --------------------------- |
| 已知 CUSIP                            | `get_instrument_by_cusip`   |
| 已知 ticker                           | `search_instruments(SYMBOL_SEARCH)` |
| 知道公司名一部分                       | `search_instruments(DESCRIPTION_SEARCH)` |
| 想要财务基本面                         | `search_instruments(FUNDAMENTAL)` |

## CUSIP 与 ISIN 的关系

CUSIP 是美国 9 位证券代码；ISIN 是国际 12 位证券代码（含国家前缀
`US` + 9 位 CUSIP + 1 位校验码）。Schwab 只接受 CUSIP；要从 ISIN 转
CUSIP，截取第 3-11 位即可（仅适用美股 ISIN）。

```python
def isin_to_cusip(isin: str) -> str:
    assert isin.startswith("US") and len(isin) == 12
    return isin[2:11]
```

## 常见错误

| `error`                                          | 原因                                            |
| ------------------------------------------------ | ----------------------------------------------- |
| `SchwabValidationError(field="cusip")`           | 不是 9 位字母数字                                |
| `SchwabValidationError(field="symbols")`        | 长度 0 或 > 50；含小写或非法字符                |
| `SchwabValidationError(field="projection")`     | 拼错，参考上表                                  |
| `instruments == []`                             | 没找到匹配；试 `SEARCH` projection 放宽 |

## 不要做的事

- **不要** 用 `search_instruments` 当成 quote tool —— 它返回的是元数据
  与基本面，不是实时价格。要价格用 `get_quote` / `get_quotes`。
- **不要** 在 batch 里混 ticker + CUSIP —— `search_instruments` 不识别
  CUSIP，CUSIP 只走 `get_instrument_by_cusip`。

## 参考

- Quote 报价：[`tool-reference-quotes.md`](tool-reference-quotes.md)
- 验证错误处置：[`../troubleshooting/validation-overview.md`](../troubleshooting/validation-overview.md)
