# Troubleshooting — `SchwabValidationError`

`SchwabValidationError` 是 MCP server 在 **本地 Pydantic 层** 拒绝的输入错误，**不消耗** Schwab API 配额。错误返回时一定带 `field` 字段指向出错参数。

---

## 1. symbol 正则不匹配

- **Symptom**：`{"error":"SchwabValidationError","field":"symbol","message":"...does not match…"}` / 类似 `field="symbols"` 在 `get_quotes` 上。
- **Root cause**：常见 4 种：
  - 小写 ticker（`"aapl"`）—— 必须 UPPERCASE。
  - 含非法字符（如 `"BRK.B "`，尾随空格）。
  - 把指数当股票（`"SPX"` 而非 `"$SPX"`）。
  - 把 OSI option 当作 stock（OSI 只能进 `get_quote/get_quotes`，不能进 `get_option_chain`）。
- **检查命令**：对照 `tool-reference.md` §1 的合法格式表。
- **修复策略**：
  ```python
  # ❌ get_quote("aapl") → 报错
  # ✅
  get_quote("AAPL")
  get_quote("$SPX")                          # 指数
  get_quote("BRK.B")                         # ETF / 含点
  get_quote("BF/B")                          # 含斜杠
  get_quote("AAPL  240119C00170000")         # OSI 21 字符（root 6 字符空格右补齐）
  ```
- **验证**：重试同一调用，错误消失。

---

## 2. `get_price_history` 笛卡尔积非法

- **Symptom**：`{"error":"SchwabValidationError","field":"period_type|period|frequency_type|frequency"}`。
- **Root cause**：`(period_type, period, frequency_type, frequency)` 四元组只接受**受限组合**，非法组合 Schwab 服务端会 silently 400，MCP server 在 Pydantic 层提前拦截。常见错误：
  - `period_type="DAY"` 配 `frequency_type="DAILY"`（`DAY` 只允许 `MINUTE`）。
  - `period_type="MONTH"` 给了 `frequency` 值（应留空）。
  - `period_type="YEAR_TO_DATE"` 给了 `period` 值（应留空）。
- **检查命令**：对照 `tool-reference.md` §3 的笛卡尔积合法表。
- **修复策略**：
  ```python
  # ❌ 拉日 K 一年，写错：
  get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                    frequency_type="DAILY")  # 报错
  # ✅ 拉 6 月日 K：
  get_price_history(symbol="VOO", period_type="MONTH", period="SIX_MONTHS",
                    frequency_type="DAILY")
  # ✅ 拉今日分钟 K：
  get_price_history(symbol="VOO", period_type="DAY", period="ONE_DAY",
                    frequency_type="MINUTE", frequency="EVERY_FIVE_MINUTES")
  ```
- **验证**：返回非空 `candles` 列表。

---

## 3. `get_quotes` 超过 50 symbol

- **Symptom**：`{"error":"SchwabValidationError","field":"symbols","message":"max length 50"}`。
- **Root cause**：单次 `get_quotes` 调用 symbols 列表长度 > 50（Schwab 硬上限，server 端 Pydantic 拦截）。
- **检查命令**：
  ```python
  print(len(symbols))   # 必须 ≤ 50
  ```
- **修复策略**：自行分批：
  ```python
  def chunked(lst, n=50):
      for i in range(0, len(lst), n):
          yield lst[i:i+n]

  results = []
  for batch in chunked(symbols, 50):
      results.append(await get_quotes(symbols=batch, fields=["QUOTE"]))
  ```
- **验证**：每批返回成功，无 validation error。

---

## 4. OSI option symbol 格式错

- **Symptom**：`{"error":"SchwabValidationError","field":"symbol","message":"invalid OSI format"}`。
- **Root cause**：OSI 必须**精确 21 字符**，违反 4 种之一：
  - root 不足 6 字符未空格右补齐（`"AAPL240119C00170000"` 缺 2 个空格 = 19 字符 ❌）。
  - 日期不是 `YYMMDD`（`"AAPL  2024-01-19C00170000"` 含 `-` ❌）。
  - C/P 字段缺失或非 `C`/`P`。
  - strike 不是 8 位整数（×1000 后向上取整，`"AAPL  240119C00170"` 缺 5 位 ❌）。
- **检查命令**：
  ```python
  symbol = "AAPL  240119C00170000"
  assert len(symbol) == 21, f"OSI 必须 21 字符，当前 {len(symbol)}"
  assert symbol[6:12].isdigit(), "YYMMDD 必须 6 位数字"
  assert symbol[12] in ("C", "P"), "第 13 位必须 C 或 P"
  assert symbol[13:].isdigit() and len(symbol[13:]) == 8, "strike 必须 8 位整数"
  ```
- **修复策略**：
  ```python
  def build_osi(root: str, expiry_yymmdd: str, c_or_p: str, strike_dollars: float) -> str:
      assert c_or_p in ("C", "P")
      strike_int = int(round(strike_dollars * 1000))
      return f"{root.upper():<6}{expiry_yymmdd}{c_or_p}{strike_int:08d}"

  build_osi("AAPL", "240119", "C", 170.0)   # → "AAPL  240119C00170000"
  build_osi("BRK/B", "240419", "P", 350.0)  # → "BRK/B 240419P00350000"
  ```
- **验证**：重试 `get_quote(symbol=osi)` 返回 200 OK，含 option-specific 字段（`delta`, `gamma`, `theta`, `vega`）。

---

## 不要做的事

- **不要** 跳过 `SchwabValidationError` 直接重试同一参数（必然再次失败）。
- **不要** 把验证错误当成 server bug 上报（绝大多数是输入参数问题；先对照本文 4 类症状）。
- **不要** 用正则在 agent 侧做二次验证，server 已经做了；agent 只需修正参数后重试一次。
