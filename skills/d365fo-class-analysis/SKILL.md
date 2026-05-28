---
name: d365fo-class-analysis
description: >
  Use when user asks about D365FO classes, class hierarchies, CoC extensions, or event handlers.
  "what classes handle purchase invoice posting", "who extends SalesFormLetter",
  "CoC extensions on PurchFormLetter_Invoice", "class hierarchy for SalesLineType",
  "event handlers for SalesTable insert", "which class handles ledger posting",
  "find all extensions of VendInvoiceInfoTable", "what event subscribers exist for CustTable",
  "how many customizations are on PurchFormLetter"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Class Analysis

Search and analyze classes, Chain of Command extensions, and event handler subscriptions
across all models in the D365FO index.

## When to use

- User asks which class handles a specific business process (posting, validation, calculation)
- User asks about class hierarchies or base class chains
- User wants to find all CoC (Chain of Command) extensions on a class
- User wants to find Data Event Handler subscriptions on a table or class
- User is assessing the customization footprint before an upgrade or refactoring
- User wants to understand which custom models touch a specific standard class

## Workflow

1. **Find candidate classes.** Call `search_classes(keywords)` with business-process terms
   (e.g., `"purchase invoice post"`, `"sales order validation"`).

2. **Get class details.** Call `get_class_info(className)` on the top 1-3 matches to get the
   method list, base class, interfaces, and which model the class belongs to.

3. **Check CoC extensions.** Call `find_coc_extensions(className)` to discover all Chain of
   Command extension classes across all models in the index.

4. **Check event handlers.** Call `find_event_subscribers(className)` to list Data Event Handler
   subscriptions for the table or class.

5. **Summarize** with the tables below, highlighting which classes are extended and in which
   custom models.

## Output Format

### Class search results

| Class | Base Class | Module | Model | Method Count |
|---|---|---|---|---|
| PurchFormLetter_Invoice | PurchFormLetter | ApplicationSuite | ApplicationSuite | 42 |

### CoC Extensions

| Extension Class | Extending Model | Extended Methods |
|---|---|---|
| PurchFormLetter_Invoice_MyExt | MyCustomModel | run, validate |
| PurchFormLetter_Invoice_ISVExt | ISVModel | postRun |

### Event Subscriptions (Data Event Handlers)

| Subscriber Class | Subscriber Method | Event | Model |
|---|---|---|---|
| MyEventHandler | onPurchInvoicePosted | Inserted | MyCustomModel |

## Notes

- Use the CoC extension count to assess **upgrade risk**: zero extensions = safe; multiple
  extensions = coordinate with model owners before changing the class.
- If `find_coc_extensions` returns extensions in the same model as the question originator,
  show those first — they are most relevant.
- For posting classes, also check `run()`, `post()`, and `validate()` method overrides in the
  CoC chain.
- If the user asks about a table's methods (not a standalone class), route to the
  `d365fo-table-search` skill and use `get_table_methods` there.
