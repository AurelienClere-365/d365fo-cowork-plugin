---
name: d365fo-table-search
description: >
  Use when user asks about D365FO table metadata, fields, data types, or relationships.
  "what fields does SalesTable have", "how are PurchTable and VendTable related",
  "table structure for CustTable", "mandatory fields in InventTable",
  "indexes on LedgerJournalTable", "join key between SalesTable and SalesLine",
  "table schema for VendTrans", "find tables related to invoice posting",
  "what is the primary key of SalesTable", "which fields are required on PurchTable"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Table Search

Explore table definitions, field lists, data types, relations, and indexes from the D365FO
metadata index.

## When to use

- User asks about fields, EDTs, or mandatory flags on a specific table
- User asks how two tables are related (FK relations, join conditions, cardinality)
- User asks about indexes, primary keys, or unique constraints
- User asks which tables belong to a business area or process
- User is building a report, integration spec, or entity diagram and needs join keys

## Workflow

1. **Identify the target table(s).** Extract table names from the question. If ambiguous, call
   `search_tables(keywords)` to find candidates and confirm the best match.

2. **Retrieve field metadata.** Call `get_table_info(tableName)` to get the full field list:
   name, EDT, base type, mandatory flag, and label.

3. **Retrieve relations (if asked).** Call `get_table_relations(tableName)` for FK links to
   other tables. Do this for each table when the user asks about joins.

4. **Retrieve indexes (if asked).** Call `get_table_indexes(tableName)` for index definitions,
   uniqueness, and whether they are the cluster index.

5. **Retrieve methods (if asked).** Call `get_table_methods(tableName)` for method signatures.

6. **Format and present** using the Output Format tables. Filter columns to what the user
   actually needs — do not dump all 200+ fields unless explicitly requested.

## Output Format

### Field list

| Field | EDT / Base Type | Mandatory | Label | Notes |
|---|---|---|---|---|
| SalesId | SalesIdBase (str 20) | Yes | Sales order | Primary key segment |
| CustAccount | CustAccount (str 20) | Yes | Customer account | FK to CustTable |
| CurrencyCode | CurrencyCode (str 3) | Yes | Currency | ISO 4217 code |

### Relations

| Relation | Related Table | Join Condition | Cardinality |
|---|---|---|---|
| CustTable | CustTable | SalesTable.CustAccount = CustTable.AccountNum | N:1 |
| SalesLine | SalesLine | SalesTable.SalesId = SalesLine.SalesId | 1:N |

### Indexes

| Index Name | Fields | Unique | Notes |
|---|---|---|---|
| SalesIdx | SalesId | Yes | Cluster index |
| CustIdx | CustAccount | No | Non-unique lookup |

## Notes

- EDTs shown as `TypeName (base: ActualType length)` — e.g., `SalesIdBase (str 20)`.
- For large tables (100+ fields), group by category: identifiers, FK references,
  amounts, dates, flags. Only expand a category if the user asks about it.
- If a table is not found by exact name, try `search_tables` with keywords from the
  business concept (e.g., "sales line" instead of "SalesLine").
- See [references/field-types.md](references/field-types.md) for common EDT families.
