---
name: d365fo-report-discovery
description: >
  Use when user asks about D365FO reports, SSRS reports, or print management.
  "does a standard report exist for vendor aging", "what datasets does PurchPurchaseOrder report use",
  "find reports related to sales confirmation", "what data provider class does a report use",
  "find the SSRS report for customer statement", "which report covers open purchase orders",
  "existing report for inventory value", "report datasets for LedgerTransVoucher"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Report Discovery

Find existing SSRS reports and inspect their dataset definitions before building new ones.
Avoids duplicating standard reports and reveals the data provider classes behind them.

## When to use

- User needs to know if a standard D365FO report covers a business requirement
- User is extending or replacing a standard report and needs its dataset/DP class
- User is documenting print management requirements in an SFD
- User wants to know which data provider class a report uses (for CoC extension)

## Workflow

1. **Search for reports.** Call `search_reports(query)` with business keywords
   (e.g. "vendor aging", "purchase order", "sales confirmation", "customer statement").

2. **Get report metadata.** Call `get_report(reportName)` — returns:
   - Report datasets and their data provider (DP) class
   - Report design names
   - Whether the report is part of print management

3. **Identify the data provider class.** The DP class (extends `SrsReportDataProviderBase`
   or `SrsReportDataProviderPreProcess`) is the extension point for adding fields or
   changing report data. Note it for the technical spec.

4. **Recommend.**
   - Standard report found → document it. If customisation is needed, the CoC extension
     point is on the DP class `processReport()` method.
   - No standard report → describe the dataset needed and suggest a new report with a
     SysOperation-based data provider.

## Output Format

### Report match

| Report name | Design | Module | Print management |
|---|---|---|---|
| PurchPurchaseOrder | Report | Procurement | Yes |
| VendAgingReport | Report | Accounts payable | No |

### Report datasets

| Dataset name | Data provider class | Key table(s) |
|---|---|---|
| PurchPurchaseOrderDS | PurchPurchaseOrderDP | PurchTable, PurchLine |
| VendorDS | VendTableDP | VendTable |

### Extension approach (if customisation needed)

```
Extension point : PurchPurchaseOrderDP::processReport()  (CoC)
Add field to    : PurchPurchaseOrderTmp (temp table — add via table extension)
Expose in SSRS  : Add field to dataset in Visual Studio report designer
```

## Notes

- D365FO reports use temporary tables (`TmpTable`) as the dataset source — you cannot
  directly add fields from base tables to a report without modifying the DP class and
  its temp table.
- Print management reports (e.g. purchase order, sales confirmation) have strict upgrade
  implications — prefer CoC on the DP class over full replacement.
- `SrsReportDataProviderPreProcess` DP classes run as a batch before rendering — large
  data volumes are processed async; take this into account in the SFD.