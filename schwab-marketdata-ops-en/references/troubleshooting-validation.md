# Troubleshooting — `SchwabValidationError` (legacy redirect)

> This file is preserved for backward compatibility with old
> references; the content has been reorganized into the
> [`troubleshooting/`](troubleshooting/) subdirectory.

## Source

For the original Chinese version, see
[`../../schwab-marketdata-ops/references/troubleshooting-validation.md`](../../schwab-marketdata-ops/references/troubleshooting-validation.md).

## New locations

Split by `field` into individual files:

| Source                            | Child file                                                                          |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| Symbol regex mismatch             | [`troubleshooting/validation-symbol.md`](troubleshooting/validation-symbol.md)      |
| Price history Cartesian product invalid | [`troubleshooting/validation-pricehistory-cartesian.md`](troubleshooting/validation-pricehistory-cartesian.md) |
| `get_quotes` exceeded 50 symbols   | [`troubleshooting/validation-batch-50.md`](troubleshooting/validation-batch-50.md)   |
| OSI option symbol format error    | [`troubleshooting/validation-osi-format.md`](troubleshooting/validation-osi-format.md) |

## Entry point

Main entry (routing table + decision flow):
[`troubleshooting/validation-overview.md`](troubleshooting/validation-overview.md)

OSI encoding deep dive:
[`concepts/osi-option-symbol.md`](concepts/osi-option-symbol.md)
