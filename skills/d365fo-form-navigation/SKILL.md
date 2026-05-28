---
name: d365fo-form-navigation
description: >
  Use when user asks about D365FO forms, menu items, workspace tiles, or UI navigation.
  "where is vendor invoice journal in the menu", "what data sources does PurchTable form have",
  "which menu item opens VendInvoiceJournal", "find the workspace for accounts payable",
  "what forms use CustTable as a data source", "which tile links to vendor invoices",
  "find all menu items under Procurement module", "form metadata for SalesTable"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Form & Navigation Discovery

Explore form definitions, data sources, menu items, workspace tiles, and navigation
paths within D365FO — without opening Visual Studio or a live AOS.

## When to use

- User needs to know the data sources (tables) backing a specific form
- User wants to find which menu item or tile navigates to a feature
- User is writing a form extension and needs the form's data source structure first
- User is documenting navigation paths for a functional design document
- User wants to find all forms related to a business area (e.g. "procurement")

## Workflow

1. **Identify the target.** Extract form names, module names, or business concepts.

2. **Look up the form.** Call `get_form(formName)` — returns data sources, the source
   file path, and the top-level form type (ListPage, SimpleList, Details, etc.).

3. **If form name is unknown**, call `search_any(query)` with the business concept and
   filter results to `AxForm` type.

4. **Look up menu items.** Call `get_menu_item(menuItemName)` — returns the object it
   points to (form, report, class), the menu item type (Display/Action/Output), and
   the label.

5. **Look up tiles.** Call `search_tiles(query)` to find workspace tiles by business
   concept, then follow up with the tile's linked menu item if needed.

6. **Look up workspaces.** Call `search_workspaces(query)` to find the workspace
   descriptor and its constituent tiles and KPIs.

## Output Format

### Form data sources

| Data source | Table | Join mode | Link type |
|---|---|---|---|
| SalesTable | SalesTable | — | Root |
| SalesLine | SalesLine | InnerJoin | 1:N child |
| CustTable | CustTable | OuterJoin | N:1 reference |

### Menu item

| Property | Value |
|---|---|
| Name | VendInvoiceJournalListPage |
| Type | Display |
| Object | VendInvoiceJournal (Form) |
| Label | Vendor invoice journal |
| Module | Accounts payable |

## Notes

- Form names in D365FO usually match the primary table name (e.g. `SalesTable` form for
  the `SalesTable` table). Start there if the user gives a table name.
- Extensions of a form live in `*_Extension` objects — check `find_extensions(formName)`
  if the user asks what customisations exist on the form.
- Workspace tiles are the entry point to most functional areas; search tiles first when
  a user describes a functional feature rather than a technical object name.