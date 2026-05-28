---
name: d365fo-enum-edt
description: >
  Use when user asks about D365FO Extended Data Types (EDTs) or enums.
  "what EDT should I use for a reference number field", "does an enum exist for approval status",
  "suggest an EDT for a percentage field", "what base type is CustAccount",
  "find enums related to vendor status", "what values does PurchStatus have",
  "create an EDT for a new currency amount field", "what is the parent EDT of SalesIdBase"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Enum & EDT Discovery

Find the right Extended Data Type or enum before creating a new one. Avoids duplicate types
and ensures new fields inherit correct formatting, labels, and validation.

## When to use

- User needs an EDT for a new table field and wants to reuse an existing type
- User wants to check if an enum value or enum type already exists before adding one
- User wants to understand the EDT hierarchy (base types, parent EDTs)
- User is scaffolding a new field on a table extension and needs the correct type
- User wants to generate a new EDT or enum skeleton from the CLI

## Workflow

1. **Identify the business concept.** Extract the data concept (e.g. "reference number",
   "approval status", "percentage") from the question.

2. **Search for existing EDTs.** Call `search_edts(query)` with the concept keywords.
   If results are sparse, try synonyms (e.g. "Ref", "Id", "Pct").

3. **Get EDT details.** Call `get_edt_details(edtName)` for the most relevant hits:
   base type, string length, extends chain, and which tables already use it.

4. **Use suggest_edt if unsure.** Call `suggest_edt(fieldDescription)` — the CLI ranks
   candidate EDTs by semantic similarity. Present the top 3 with their base types.

5. **Search enums if the field is a fixed-value list.** Call `search_enums(query)` then
   `get_enum_details(enumName)` to see all defined values.

6. **Recommend or scaffold.**
   - If a suitable EDT/enum exists: recommend it with justification.
   - If none fits: describe what a new type should extend and suggest calling
     `generate_edt(name, baseType, extends)` or `generate_enum(name, values[])`.

## Output Format

### EDT recommendation

| EDT | Base Type | Length | Extends | Used on (sample tables) | Fit |
|---|---|---|---|---|---|
| PurchReqRefNum | str | 30 | RefRecId | PurchReqTable, PurchReqLine | High |
| VendExternalItemId | str | 30 | — | VendTable | Medium |

### Enum values

| Enum | Value | Label | Int value |
|---|---|---|---|
| PurchStatus | Backorder | Backorder | 1 |
| PurchStatus | Received | Received | 3 |
| PurchStatus | Invoiced | Invoiced | 4 |

## Notes

- Always prefer **reusing an existing EDT** over creating a new one — it inherits the label,
  help text, string length, and `extends` chain automatically.
- For amounts: use an EDT that extends `AmountMST` or `Amount` (Real base type).
- For quantities: extend `Qty` (Real).
- For dates: extend `TransDate` (Date).
- For free-text notes: extend `Notes` (str 1000) or `Description` (str 60).
- Enums are value types — changes to existing enum values are additive only in upgrades.
  Always check `get_enum_details` before adding a new value to a standard enum.