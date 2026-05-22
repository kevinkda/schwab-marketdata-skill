# Troubleshooting — `SchwabValidationError` (legacy redirect)

> 本文件为兼容旧引用而保留，内容已重组到
> [`troubleshooting/`](troubleshooting/) 子目录。

## 新位置

按 `field` 拆分到独立子文件：

| 来源                              | 子文件                                                                              |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| symbol 正则不匹配                  | [`troubleshooting/validation-symbol.md`](troubleshooting/validation-symbol.md)      |
| price history 笛卡尔积非法         | [`troubleshooting/validation-pricehistory-cartesian.md`](troubleshooting/validation-pricehistory-cartesian.md) |
| `get_quotes` 超 50 symbol          | [`troubleshooting/validation-batch-50.md`](troubleshooting/validation-batch-50.md)   |
| OSI option symbol 格式错           | [`troubleshooting/validation-osi-format.md`](troubleshooting/validation-osi-format.md) |

## 入口

总入口（路由表 + decision flow）：
[`troubleshooting/validation-overview.md`](troubleshooting/validation-overview.md)

OSI 编码深度：
[`concepts/osi-option-symbol.md`](concepts/osi-option-symbol.md)
