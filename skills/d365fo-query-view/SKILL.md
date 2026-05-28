---
name: d365fo-query-view
description: >
  Use when user asks about D365FO queries or views.
  "does a query exist for open purchase orders", "what tables does VendTransOpenPerDate view join",
  "find queries related to customer transactions", "view definition for LedgerTransVoucher",
  "what is the SQL equivalent of CustTransOpen view", "reuse an existing query for a report",
  "data sources in PurchPurchaseOrderQuery", "find views that include InventTrans"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Query & View Discovery

Find and inspect reusable AxQuery and AxView definitions before building new data structures.
Queries and views are the building blocks of reports, data entities, and form data sources.

## When to use

- User is building a report or data entity and wants to reuse an existing query
- User wants to understand what a view exposes and how it joins its sources
- User is looking for the canonical D365FO query for a business concept
  (e.g. "open vendor transactions", "posted sales orders")
- User wants to verify whether a view can serve as the basis for an OData entity

## Workflow

1. **Search for existing queries.** Call `search_queries(query)` with business keywords
   (e.g. "open purchase", "vendor trans", "ledger voucher").

2. **Get query details.** Call `get_query(queryName)` — returns data sources, ranges,
   sorting, and the join structure.

3. **Search for views.** Call `search_views(query)` for materialised view objects.

4. **Get view details.** Call `get_view(viewName)` — returns the fields projected, the
   underlying source query or table joins, and computed columns.

5. **Recommend.** If a query or view covers the user's need, present it as a reuse
   candidate with an explanation of what it already provides vs. what would need
   extending. If nothing fits, describe the data sources needed for a new query/view.

## Output Format

### Query data sources

| Data source alias | Table / View | Join type | Ranges |
|---|---|---|---|
| VendTrans | VendTrans | Root | TransType = Invoice |
| VendTable | VendTable | InnerJoin | — |
| VendTransOpen | VendTransOpen | ExistsJoin | — |

### View fields

| Field | Source table | Source field | Notes |
|---|---|---|---|
| AccountNum | VendTable | AccountNum | Vendor account |
| AmountCur | VendTrans | AmountCur | Open amount in transaction currency |
| DueDate | VendTrans | DueDate | — |

## Notes

- D365FO views are indexed — they can be used in other queries and as data entity
  sources. Prefer a view over a raw table join in data entities when the view already
  exists.
- Query ranges constrain what data is returned by default — check them before reusing
  a query in a wider context (they may filter too aggressively for your use case).
- Standard query names follow the pattern `<Module><BusinessConcept>` (e.g.
  `VendTransOpenPerDate`, `PurchPurchaseOrderMaintain`).