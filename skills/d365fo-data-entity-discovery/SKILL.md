---
name: d365fo-data-entity-discovery
description: >
  Use when user asks about D365FO data entities for integration, DMF import/export, or OData.
  "what data entity should I use to import vendor invoices via DMF",
  "which entity exposes customer invoices for OData", "import customers from Excel",
  "DMF entity for purchase orders", "OData endpoint for sales orders",
  "integration entity for inventory on-hand", "which entity should I use to export GL journals",
  "data entity for vendor master data"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Data Entity Discovery

Find the right data entity for DMF (Data Management Framework) imports, Excel exports,
OData integrations, and external system connectors.

## When to use

- User needs to import or export data using DMF / Excel / DIXF
- User needs to expose data over OData for Power BI, Logic Apps, or external APIs
- User wants to understand which entity maps to a specific business object
- User is writing an integration specification and needs entity field details
- User wants to compare multiple candidate entities for a use case

## Workflow

1. **Extract keywords** from the user's question (e.g., `"vendor invoices"`, `"customers"`,
   `"sales orders"`).

2. **Search entities.** Call `search_data_entities(keywords)` — returns entity names, target
   tables, and tags.

3. **Narrow candidates.** If more than 3 results, prefer entities tagged DMF-enabled. Use
   the highest version suffix (V2, V3) when multiple versions exist.

4. **Get entity details.** Call `get_data_entity_info(entityName)` on each candidate:
   - Target table and staging table
   - Mandatory fields
   - DMF support flag (can be used in import/export jobs)
   - OData support flag (exposed as OData endpoint)
   - Public / Private visibility

5. **Recommend** the best-fit entity. Explain why (mandatory field count, DMF + OData flags,
   staging support). If no suitable entity exists, note that a custom entity may be needed
   and suggest using the `d365fo-extension-strategy` skill.

## Output Format

### Entity comparison

| Entity | Target Table | DMF | OData | Mandatory Fields | Notes |
|---|---|---|---|---|---|
| VendorInvoiceHeaderEntity | VendInvoiceInfoTable | Yes | Yes | InvoiceId, VendAccount, Date | Header only |
| VendorInvoiceLineEntity | VendInvoiceInfoLine | Yes | Yes | InvoiceId, LineNum, ItemId | Line only |

### Mandatory fields for recommended entity

| Field | Type | Notes |
|---|---|---|
| InvoiceId | VendInvoiceId (str 20) | Unique invoice identifier |
| VendAccount | VendAccount (str 20) | Must match an existing vendor |

## Notes

- **V2 / V3 entities** are revised versions — always use the highest available version.
- **DMF vs OData:** DMF handles bulk import/export with staging; OData is for real-time
  read access and is better for Power BI and Power Automate.
- For large-volume imports (1M+ records), recommend the DMF staging approach over OData.
- If the user mentions "Excel" or "Azure Data Factory", DMF entities are the right answer.
- If the user mentions "Power BI", "Flow", or "Logic Apps", OData-enabled entities are better.
