# Common D365FO EDT Families

Reference for the most frequently encountered Extended Data Types (EDTs) in D365FO
table search output. Use this when interpreting field types returned by `get_table_info`.

---

## String types

| EDT Family | Base Type | Typical Length | Used for |
|---|---|---|---|
| AccountNum | str | 20 | Customer and vendor account numbers |
| Name | str | 100 | Person and organization names |
| Description | str | 60 | Short descriptions on transactions |
| Notes | str | 255+ | Free-text memo fields |
| ItemId | str | 20 | Item / product identifiers |
| SalesId | str | 20 | Sales order document numbers |
| PurchId | str | 20 | Purchase order document numbers |
| VendInvoiceId | str | 20 | Vendor invoice identifiers |
| CurrencyCode | str | 3 | ISO 4217 currency codes (e.g., USD, EUR) |
| LanguageId | str | 7 | BCP-47 language tags (e.g., en-US) |
| DataAreaId | str | 4 | Legal entity / company identifier |

## Numeric types

| EDT Family | Base Type | Used for |
|---|---|---|
| Amount | real | Monetary amounts in transaction currency |
| AmountMST | real | Monetary amounts in accounting currency |
| Qty | real | Inventory quantities |
| Price | real | Unit prices |
| Weight | real | Physical weight (kg or lbs depending on UOM) |
| Percent | real | Percentage values (stored as 0-100, NOT 0-1) |
| RecId | int64 | Surrogate primary key — present on ALL tables |
| RefRecId | int64 | Foreign key to another table's RecId |
| Partition | int64 | Virtual company partition (system-managed) |

## Date and time types

| EDT Family | Base Type | Notes |
|---|---|---|
| TransDate | date | Transaction date — no time component |
| FromDate | date | Range start date |
| ToDate | date | Range end date |
| CreatedDateTime | utcdatetime | Record creation timestamp (UTC) |
| ModifiedDateTime | utcdatetime | Last modification timestamp (UTC) |

`utcdatetime` is stored in UTC. Use `DateTimeUtil::applyTimeZone` in X++ to convert
to the user's time zone for display.

## Boolean / flag types

| EDT | Base Type | Notes |
|---|---|---|
| NoYes | enum | 0=No, 1=Yes — used for all boolean flags in D365FO |
| boolean | int | Raw int 0/1 — rare; prefer NoYes for new fields |

## Common enum types

| Enum | Values | Used for |
|---|---|---|
| SalesStatus | Backorder=0, Delivered=1, Invoiced=2, Cancelled=3 | Sales order status |
| PurchStatus | Backorder=0, Received=1, Invoiced=2, Cancelled=3 | Purchase order status |
| DocumentStatus | None, PurchaseOrder, PackingSlip, Invoice | Posting stage |
| LedgerJournalType | Daily, Vendor, Customer, BankPayment, ... | Journal classification |

---

## How mandatory is determined

A field is shown as **Mandatory = Yes** when:
- The field's `AllowEdit` = No AND `AllowEditOnCreate` = No (prevents any edit after creation), OR
- A table-level validation in `validateWrite()` enforces a non-null check, OR
- The EDT has `Mandatory` = Yes at the EDT level.

Fields that are logically required by business rules (but not enforced by metadata) may
still show as Mandatory = No — always verify with the posting logic for integration work.
