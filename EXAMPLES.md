# SFD Enrichment Examples

How a functional consultant uses the D365FO Cowork Plugin to turn workshop business
requirements into a fully technical specification — before handing it to the MCP X++ Dev
or CLI Cloud Agent for development.

---

## The Workflow

```
Workshop  ──►  SFD draft          ──►  Cowork enrichment      ──►  Dev Agent
               (business req.)         (technical details)         (MCP X++ Dev /
                                                                     CLI Cloud Agent)
```

1. **Workshop** — capture the business requirement in your SFD.
2. **Paste the requirement into Cowork** with a short framing sentence.
   The plugin adds the technical layer: tables, fields, entities, security objects,
   extension patterns, labels — all grounded in your actual D365FO metadata.
3. **Copy the enriched spec** back into the SFD as a *Technical Design* section.
4. **Hand off to the Dev Agent** — the agent has everything it needs to generate X++ code
   without asking clarifying questions about metadata.

---

## Requirement 1 — Custom field on purchase orders (track customs reference)

### Business requirement (from SFD)

> After a workshop with the import/export team:
> "We need to store a customs clearance reference number on purchase orders.
>  It should be visible on the purchase order header form and printable on the PO confirmation."

### Cowork prompts used

**Step 1 — Where to store it:**
> I have a requirement to add a customs clearance reference field to purchase orders.
> What fields already exist on PurchTable related to customs or references?
> Show me the EDT families used for reference number fields on that table.

**Step 2 — Label reuse:**
> Before I create a new label for "Customs clearance reference", check if an existing
> D365FO label already covers this concept. Also search for "customs" and "clearance".

**Step 3 — Form and print surface:**
> What data entity exposes PurchTable for DMF / OData? I need to know if my new field
> will need to be added to an entity extension too.

### Technical spec section produced

```
## Technical Design — Customs clearance reference

**Storage**
- Table extension: PurchTable.CompanyModel
- New field: CustomsClearanceRef
  - EDT: create new EDT CustomsClearanceRef extending SalesIdBase (str 20)
  - Mandatory: No
  - Label: reuse @SYS4567 "Reference" — OR create @MYMOD_001 "Customs clearance reference"
    if a more specific label is preferred (label search returned no exact match)

**Form surface**
- Form extension: PurchTable.CompanyModel
- Add StringEdit control CustomsClearanceRef to TabPage > TabPageDetails > HeaderGroup
- Position: after DeliveryDate field group

**Print / report**
- PurchPurchaseOrder SSRS report — add field via report extension
- Data source: PurchTable (already in report query)

**Entity impact**
- PurchaseOrderHeaderV2Entity maps to PurchTable — create entity extension
  PurchaseOrderHeaderV2Entity.CompanyModel to expose the new field over OData/DMF

**Extension pattern**
- CoC not required — pure data field, no logic
- If validation is needed (e.g. format check): CoC on PurchTable.validateWrite()

**Dev Agent prompt**
  "Create a table extension PurchTable.CompanyModel with a new str(20) field
   CustomsClearanceRef using EDT SalesIdBase. Add a form extension for PurchTable
   placing the new StringEdit control in the HeaderGroup tab. Add a CoC extension
   on validateWrite that skips validation if the field is empty."
```

---

## Requirement 2 — Vendor invoice automation via EDI

### Business requirement (from SFD)

> "The finance team wants to receive vendor invoices from our EDI provider as an automated
>  import. Files will arrive as XML. The system should match them against POs automatically."

### Cowork prompts used

**Step 1 — Find the right entity:**
> What data entity should I use to import vendor invoices that are matched against purchase
> orders via DMF? I need one that supports the full header and line, and works with staging.

**Step 2 — Mandatory fields:**
> Show me all mandatory fields on VendorInvoiceHeaderEntity and VendorInvoiceLineEntity.
> I need to map them to my EDI file structure.

**Step 3 — Check for existing import class:**
> What classes handle vendor invoice journal import or posting? Are any of them extended
> with CoC in a custom model in the index?

### Technical spec section produced

```
## Technical Design — EDI vendor invoice import

**Entity**
- Header: VendorInvoiceHeaderEntity (target: VendInvoiceInfoTable)
  DMF-enabled: Yes | OData: Yes | Staging table: VendInvoiceInfoTableStaging
- Line:   VendorInvoiceLineEntity (target: VendInvoiceInfoLine)
  DMF-enabled: Yes | OData: Yes | Staging table: VendInvoiceInfoLineStaging

**Mandatory fields to map from EDI**
  Header: InvoiceId, VendAccount, InvoiceDate, CurrencyCode, LedgerAccount
  Line  : InvoiceId, LineNum, ItemId, Qty, UnitPrice

**Import flow**
- Use DMF import project with staging enabled
- Validation class: VendInvoiceInfoTable.validateWrite() — check PO match
- Matching: field PurchId on VendInvoiceInfoLine matched against PurchTable.PurchId

**Existing customizations**
- VendInvoiceInfoTable: 1 CoC extension found in CompanyModel on validateWrite
  → coordinate with model owner before modifying matching logic

**Automation hook**
- Data Event Handler on VendInvoiceInfoTable.Inserted → trigger matching job
- Or: use Recurring Integration API to push from EDI middleware directly

**Dev Agent prompt**
  "Create a Data Event Handler on VendInvoiceInfoTable DataEventType::Inserted
   that calls a new class CompanyVendInvoiceMatchService.matchToPurchaseOrder(vendInvoice).
   The matching logic should look up PurchTable by PurchId on the invoice line
   and set the MatchStatus field. Use a try/catch and log failures to Infolog."
```

---

## Requirement 3 — Role-based access: purchasing agent can view, not approve

### Business requirement (from SFD)

> "Workshop with IT security and AP team:
>  Purchasing agents must be able to view vendor payment journals but must NOT be able
>  to post or approve them. Segregation of duties is required."

### Cowork prompts used

**Step 1 — What roles currently exist:**
> Which privileges give read-only access to LedgerJournalTable for vendor payments?
> Which roles include those privileges?

**Step 2 — What to block:**
> Which privilege allows posting vendor payment journals? Which roles include it?
> I need to identify the SoD conflict if a user has both read and post.

**Step 3 — Least privilege:**
> What is the least-privilege role I should assign for view-only access to vendor payment
> journals without any posting or approval rights?

### Technical spec section produced

```
## Technical Design — Vendor payment journal access (SoD)

**Read-only access**
  Privilege: VendPaymentJournalView (Read on LedgerJournalTable)
  Duty     : VendPaymentJournalInquire
  Role     : AccountsPayableClerk  ← assign this for view-only users

**Posting/approval access (to EXCLUDE for purchasing agents)**
  Privilege: LedgerJournalizeVendPaymentProcess (FullControl on LedgerJournalTable)
  Duty     : VendPaymentJournalMaintain
  Roles    : AccountsPayablePaymentsClerk, AccountsPayableManager

**SoD Rule to configure**
  Conflicting duty pair: VendPaymentJournalMaintain + VendPaymentJournalInquire
  → Both covered by AccountsPayablePaymentsClerk — do NOT assign this role to
    purchasing agents who have any approval duty

**Custom role (if needed)**
  If AccountsPayableClerk has too much access:
  - Create a new Security Role: CompanyPurchAgentRole
  - Add duty: VendPaymentJournalInquire only
  - Do NOT include VendPaymentJournalMaintain or any approval duty

**Dev Agent prompt**
  "Create a new Security Role CompanyPurchAgentReadOnly with a single duty
   VendPaymentJournalInquire. Do not include any Create, Update, or FullControl
   privileges on LedgerJournalTable or VendPaymentJournal objects."
```

---

## Requirement 4 — Notification when a sales order is confirmed

### Business requirement (from SFD)

> "Sales operations team: when a sales order status changes to Confirmed (Delivery),
>  an email notification must be sent to the account manager. This is for all companies."

### Cowork prompts used

**Step 1 — Find the right event:**
> What event on SalesTable fires when the sales order status changes to Confirmed?
> Are there existing event handlers subscribed to SalesTable update events?

**Step 2 — Find the class that changes status:**
> What class sets the SalesStatus to Delivered/Confirmed on SalesTable?
> Are there CoC extensions on that class in any custom model?

**Step 3 — Extension pattern:**
> Should I use a CoC extension or a Data Event Handler to react to SalesTable status
> changes if I only need to send an email and don't need to modify the process behavior?

### Technical spec section produced

```
## Technical Design — Sales order confirmation notification

**Trigger**
- Use Data Event Handler on SalesTable DataEventType::Updated
  Filter: this.SalesStatus changed to SalesStatus::Backorder (= "Confirmed delivery")
  Note: SalesStatus::Backorder is the D365FO enum value for "Confirmed" state

**Existing handlers to check**
  search returned: 2 existing DataEventHandler subscribers on SalesTable::Updated
  → review CompanyModel.SalesTableEventHandler before adding a new one (avoid duplicates)

**Notification mechanism**
  Options (choose one):
  A) SysEmailTable — send via D365FO email template engine (recommended, multi-language)
  B) Business Event — publish a Business Event and connect to Power Automate for email

  Recommended: Business Event (no AOS email dependency, Power Automate handles routing)
  Business Event class: SalesOrderConfirmedBusinessEvent (check if standard event exists)

**Account manager field**
  Field to derive account manager: SalesTable.SalesResponsible (mapped to HcmWorker)
  Worker email: DirPersonUser.User → SysEmailTable lookup

**Dev Agent prompt**
  "Create a DataEventHandler class CompanySalesOrderNotificationHandler subscribing
   to SalesTable DataEventType::Updated. When SalesStatus changes to Backorder,
   look up the account manager via SalesTable.SalesResponsible, resolve their email
   from DirPersonUser, and send an email using SysEmailTable with template id
   'SalesOrderConfirmed'. Only fire if the old SalesStatus was not already Backorder."
```

---

## Requirement 5 — New field: approval tier on vendor master

### Business requirement (from SFD)

> "Procurement workshop: vendors need an approval tier (Bronze / Silver / Gold / Platinum)
>  to drive automatic PO approval thresholds. The tier should be visible on the vendor form
>  and filterable in vendor lists."

### Cowork prompts used

**Step 1 — Data model:**
> I need to add an approval tier (enum: Bronze, Silver, Gold, Platinum) to VendTable.
> Show me existing enum fields on VendTable to understand the naming convention used.
> Also find any existing D365FO enum that already has tier-like values.

**Step 2 — Label reuse:**
> Search D365FO labels for "tier", "approval tier", "vendor tier", and "level".
> I want to reuse existing labels where possible.

**Step 3 — Security impact:**
> Who can edit VendTable fields — which roles have Update access? I need to know
> if the new field needs its own privilege or inherits from existing VendTable access.

### Technical spec section produced

```
## Technical Design — Vendor approval tier

**Enum**
  New enum: CompanyVendApprovalTier (in CompanyModel)
  Values  : Bronze=0, Silver=1, Gold=2, Platinum=3
  No matching standard D365FO enum found — create new
  Label   : @MYMOD_002 "Approval tier" (label search: @SYS4890 "Level" — too generic)

**Storage**
  Table extension: VendTable.CompanyModel
  New field: ApprovalTier (EDT: CompanyVendApprovalTier, base: enum)
  Mandatory: No (default = Bronze=0)

**Form surface**
  Form extension: VendTable.CompanyModel
  Control: ComboBox ApprovalTier
  Location: FastTab VendTableTabPageSetup > Group: General

**List page filter**
  Form extension: VendTableListPage.CompanyModel
  Add grid column ApprovalTier to VendTableListPage grid

**Security**
  Update access on VendTable already covered by:
    Duty: VendVendorMaintain → Role: AccountsPayableAccountant
  New field inherits from VendTable extension — no separate privilege needed
  unless field-level security is required (it is not, per workshop decision)

**PO threshold logic**
  PO auto-approval class: PurchAutoApprove (found via class search)
  Extension point: CoC on PurchAutoApprove.canAutoApprove() — check vendor tier before
  allowing automatic approval above threshold

**Dev Agent prompt**
  "1. Create enum CompanyVendApprovalTier (Bronze=0, Silver=1, Gold=2, Platinum=3).
   2. Create table extension VendTable.CompanyModel with enum field ApprovalTier
      using that enum.
   3. Create form extension VendTable.CompanyModel adding ComboBox control for
      ApprovalTier on the General group of the VendTableTabPageSetup FastTab.
   4. Create CoC extension on PurchAutoApprove.canAutoApprove(): if vendor tier < Gold
      and amount > 50000, return false regardless of other conditions."
```

---

---

## Requirement 6 — Vendor payment priority: does the enum already exist?

### Business requirement (from SFD)

> Workshop with the AP team:
> "We want to flag vendor invoices with a payment priority — something like Low, Normal,
>  High, Urgent — so the payment clerk knows which ones to process first. This should be
>  selectable on the vendor invoice journal line."

### Cowork prompts used

**Step 1 — Check if D365FO already has this:**
> Does D365FO have an existing enum with values like Low / Normal / High / Urgent or
> similar priority levels that I could reuse for a payment priority field?
> Search enums for "priority", "urgency", "payment priority".

**Step 2 — Check the field already exists:**
> Does LedgerJournalTrans or VendTrans already have a priority or ranking field?
> Show any enum-type fields on those tables.

**Step 3 — Confirm what the developer needs to build:**
> If no existing enum fits, what should the new enum be named and what values should
> it have? Follow D365FO naming conventions.

### Technical spec section produced

```
## Technical Design — Invoice payment priority

**Enum check**
  search_enums("priority"):  PSAProjInvoicePriority found (High/Normal/Low) — 3 values only
  search_enums("urgency"):   no match
  PSAProjInvoicePriority is scoped to Project accounting — NOT suitable for AP reuse.

  Decision: create new enum CompanyVendPaymentPriority
  Values: Low = 0, Normal = 1, High = 2, Urgent = 3
  (Normal = 0 ensures blank/default rows don't appear as Urgent)
  Label: new label @MYMOD_010 "Payment priority"

**Field location**
  LedgerJournalTrans already has no priority field (confirmed via table search).
  Table extension: LedgerJournalTrans.CompanyModel
  New field: PaymentPriority (enum: CompanyVendPaymentPriority, default: Normal)

**Form location**
  Form: LedgerJournalTransVendPaym (the AP payment journal line form)
  Add ComboBox control PaymentPriority to the Lines grid

**Developer hand-off**
  Spec for developer:
  - New enum CompanyVendPaymentPriority (Low=0, Normal=1, High=2, Urgent=3)
  - Table extension LedgerJournalTrans.CompanyModel: enum field PaymentPriority, default Normal
  - Form extension LedgerJournalTransVendPaym.CompanyModel: ComboBox in Lines grid
  - No business logic in this phase — field is informational only
```

---

## Requirement 7 — Specify exactly where on the form a new field should appear

### Business requirement (from SFD)

> Workshop with the vendor management team:
> "The new 'approval tier' field (Bronze/Silver/Gold/Platinum) we agreed on for vendors
>  needs to be visible on the main vendor form. The team wants it on the General tab,
>  not buried somewhere. Where exactly should we say it goes in the spec?"

### Cowork prompts used

**Step 1 — Find the vendor form structure:**
> Show me the structure of the VendTable form — specifically what tabs and FastTabs
> exist. I need to decide where to place a new field for approval tier.

**Step 2 — Find the menu item and workspace:**
> Which menu item opens the VendTable form? Which workspace or tile leads there?
> I need to reference both in the navigation section of my SFD.

**Step 3 — Check if a similar field already exists nearby:**
> Are there other classification or tier-like fields already on VendTable that appear
> on the General tab? I want to place the new field next to similar fields.

### Technical spec section produced

```
## Technical Design — Approval tier field location on vendor form

**Form: VendTable**
  Opened via: VendTableListPage > menu item VendEdit (Display type)
  Module navigation: Accounts payable > Vendors > All vendors
  Workspace tile: VendPaymentWorkspaceTile (Accounts payable workspace)

**Tab location recommendation**
  FastTab: VendTableTabPageSetup  (label: "Purchase")
  Group:   VendTableTabPageSetupGeneralGroup  (label: "General")
  Existing enum fields in that group: PriceGroup, LineDisc, MultilineDisc, EndDisc
  → Place ApprovalTier after PriceGroup to keep classification fields together

**Navigation spec (for SFD)**
  Module  : Accounts payable
  Path    : Vendors > All vendors > [open record] > Purchase tab > General group
  Field   : Approval tier (ComboBox, values: Bronze / Silver / Gold / Platinum)

**Developer hand-off**
  Form extension VendTable.CompanyModel:
  - Add ComboBox control ApprovalTier to VendTableTabPageSetupGeneralGroup
  - Position: after PriceGroup control
  - Data source: VendTable (table extension field)
```

---

## Requirement 8 — Check if a standard report covers the requirement before specifying a new one

### Business requirement (from SFD)

> Workshop with the finance team:
> "We need a report listing open vendor invoices sorted by due date, grouped by vendor.
>  Before we ask IT to build one, does D365FO already have something we can just use?"

### Cowork prompts used

**Step 1 — Search for standard reports:**
> Does D365FO have a standard report for open vendor invoices or vendor aging?
> Search for reports related to "vendor aging", "vendor open", "due date".

**Step 2 — Understand what it covers:**
> Show me the datasets and key fields in the VendAgingReport (or equivalent).
> Does it include vendor name, invoice number, due date, and open amount in
> company currency?

**Step 3 — Gap analysis:**
> The team also wants to filter by the new ApprovalTier field we added to VendTable.
> Is that field available in the report's current dataset, or would it need an extension?

### Technical spec section produced

```
## Technical Design — Open vendor invoices by due date report

**Standard report check**
  search_reports("vendor aging"):    VendAgingReport  FOUND
  search_reports("open vendor"):     VendTransOpenPerDate query FOUND (not a print report)
  search_reports("vendor due date"): VendDueDate (SSRS report)  FOUND

  VendAgingReport covers: vendor aging buckets, not individual invoice lines
  VendDueDate covers:     individual invoices by due date — MATCHES the requirement

**VendDueDate report fields**
  Dataset: VendDueDateDS
  Includes: AccountNum, VendName, InvoiceId, DueDate, AmountMST, CurrencyCode ✅
  All required fields present — NO new report needed.

**Gap: ApprovalTier filter**
  ApprovalTier is a new extension field on VendTable.
  It is NOT currently in the VendDueDateDS dataset.
  → Developer must add a filter parameter for ApprovalTier as a report parameter extension.

**SFD decision**
  Reuse: VendDueDate standard report
  Extension required: yes — add ApprovalTier filter parameter only
  Estimated complexity: LOW (one additional parameter, no dataset restructuring)

**Developer hand-off**
  Spec for developer:
  - Extend VendDueDate report to add an optional filter parameter ApprovalTier
  - Filter applies to VendTable datasource in the existing report query
  - No change to report layout — parameter only
```

---

## Requirement 9 — Replace a polling integration with an event-driven trigger

### Business requirement (from SFD)

> Workshop with the integration team and business:
> "Right now our Power Automate flow polls D365FO every 5 minutes looking for confirmed
>  purchase orders to send to the supplier portal. The business wants real-time. Is there
>  a D365FO event we can subscribe to instead so the flow fires the moment a PO is confirmed?"

### Cowork prompts used

**Step 1 — Search for the standard event:**
> Does a standard D365FO business event fire when a purchase order is confirmed?
> Search business events for "purchase order confirmed", "PO confirmation".

**Step 2 — Check the payload:**
> Show me the payload fields of PurchaseOrderConfirmedBusinessEvent.
> The flow needs: PO number, vendor account, total amount, confirmation date.
> Are all four fields in the standard payload?

**Step 3 — Subscription path:**
> How does a functional consultant set up the subscription in D365FO?
> What menu path and what information does the admin need to fill in?

### Technical spec section produced

```
## Technical Design — Real-time PO confirmation trigger for supplier portal

**Standard business event**
  PurchaseOrderConfirmedBusinessEvent  FOUND
  Category: Procurement and sourcing
  Fires when: purchase order is confirmed via standard D365FO confirmation process

**Payload check**
  Required         Available in payload?
  PO number        ✅  PurchId
  Vendor account   ✅  VendAccount
  Total amount     ✅  TotalAmount
  Confirm date     ✅  ConfirmationDate
  → All fields present. No custom development required.

**Subscription setup (admin task — no code)**
  Menu path: System administration > Set up > Business events > Business event catalog
  Steps:
    1. Filter by Category: "Procurement and sourcing"
    2. Find PurchaseOrderConfirmedBusinessEvent > Activate
    3. Add endpoint: Microsoft Power Automate (or Azure Service Bus)
    4. Map to the existing Power Automate flow HTTP trigger

**SFD recommendation**
  Replace OData poll with: Business event subscription (zero custom code)
  Real-time: yes — event fires immediately on confirmation, no polling delay
  Power Automate change: update trigger from scheduled poll to "When a business event occurs"

**Developer hand-off**
  No X++ development required.
  Admin action only: activate event and configure endpoint in Business event catalog.
  IT admin to decommission the existing 5-minute scheduled Power Automate flow trigger.
```

---

## Requirement 10 — Identify the right integration entry point for the SFD

### Business requirement (from SFD)

> Workshop with IT and the logistics team:
> "Our new 3rd-party warehouse management system (WMS) needs to push inbound shipment
>  confirmations back into D365FO to receive against purchase orders automatically.
>  The functional spec needs to say: what D365FO entry point should the WMS call?
>  We don't want to spec the wrong thing and have IT build an integration to a dead end."

### Cowork prompts used

**Step 1 — Find existing entities for shipment/receipt:**
> What public data entities exist in D365FO for purchase order receipts or product receipts?
> Search entities for "product receipt", "purchase receipt", "packing slip", "arrival".

**Step 2 — Check if a standard service exists:**
> Is there a custom D365FO service for posting purchase order receipts programmatically?
> Search services for "purch", "receipt", "arrival".

**Step 3 — Pattern recommendation:**
> For a WMS pushing bulk shipment confirmations (50–500 lines at a time), asynchronously,
> what is the recommended D365FO integration pattern — OData, DMF, or custom service?
> What are the trade-offs for the SFD?

### Technical spec section produced

```
## Technical Design — WMS inbound shipment confirmation integration

**Entity check**
  search_data_entities("product receipt"):   PurchaseOrderReceiptHeaderEntity  FOUND
  search_data_entities("packing slip"):       PurchPackingSlipJournalEntity     FOUND
  search_data_entities("arrival"):            InventArrivalJournalEntity        FOUND

  Best match: PurchaseOrderReceiptHeaderEntity + PurchaseOrderReceiptLineEntity
  DMF enabled: Yes | Staging: Yes | OData: Yes

**Service check**
  search_services("purch receipt"): no dedicated receipt service found
  → DMF entity is the standard and recommended path

**Pattern recommendation for SFD**

  | Pattern        | Suitable? | Reason |
  |----------------|-----------|--------|
  | OData (CRUD)   | No        | Synchronous, not suited for bulk with retry |
  | DMF package    | ✅ YES    | Bulk, async, staging validation, retry built-in |
  | Custom service | No        | No standard one exists; building custom adds risk |

  Recommendation: DMF import project using PurchaseOrderReceiptHeaderEntity /
  PurchaseOrderReceiptLineEntity with staging enabled.

**SFD integration specification**
  Direction      : Inbound (WMS → D365FO)
  Method         : DMF recurring integration (REST package API)
  Entities       : PurchaseOrderReceiptHeaderEntity, PurchaseOrderReceiptLineEntity
  Trigger        : WMS posts file to DMF REST endpoint on shipment confirmation
  Validation     : DMF staging validates PO match before posting
  Error handling : Failed staging rows routed to DMF error log; WMS alerted via callback

**Developer hand-off**
  No entity extensions required — standard entities cover the fields.
  IT task: configure DMF import project + expose recurring integration endpoint to WMS team.
  Spec for WMS vendor: attach DMF staging field mapping document (generated from entity metadata).
```

---

## Requirement 11 — Specify a month-end batch process for the SFD

### Business requirement (from SFD)

> Workshop with the AP manager:
> "At month-end we want the system to automatically identify vendors with no transactions
>  in the last 18 months and flag them as 'dormant' in our new vendor status field.
>  It should run overnight on the last day of the month and email a summary to the AP manager.
>  We need this in the functional spec well enough for a developer to build it."

### Cowork prompts used

**Step 1 — Check if it already exists:**
> Does D365FO have an existing batch job or process that identifies dormant or inactive vendors?
> Search batch jobs for "dormant vendor", "inactive vendor", "vendor cleanup".

**Step 2 — Find the right tables:**
> To identify vendors with no transactions in 18 months, which tables should be checked?
> What is the last-transaction date field on VendTrans?

**Step 3 — Email summary mechanism:**
> What is the standard D365FO mechanism for sending a summary email at the end of a batch?
> I need to document this in the spec so the developer knows the expected approach.

### Technical spec section produced

```
## Technical Design — Dormant vendor month-end batch

**Existing job check**
  find_batch_jobs("dormant vendor"):   no results
  find_batch_jobs("inactive vendor"):  no results
  → New process required — no standard job to reuse.

**Data model**
  Source table: VendTrans — field TransDate (last transaction date)
  Filter: VendTrans latest TransDate per VendAccount < today minus 18 months
  Vendors with zero VendTrans rows also qualify as dormant

  Status field target: VendTable.CompanyModel.VendorStatus (new enum field)
    from Requirement 5 pattern — or new field CompanyDormantFlag (boolean) if simpler

**Process specification**
  Name        : Dormant vendor identification (CompanyVendDormantBatch)
  Trigger     : Scheduled — last calendar day of each month, 02:00
  Scope       : All active companies (cross-company)
  Parameters  : InactivityMonths (default: 18), NotifyEmail (AP manager email address)
  Logic       :
    1. Find VendTable records where max(VendTrans.TransDate) < today - InactivityMonths
       OR no VendTrans rows exist at all
    2. Set CompanyDormantFlag = Yes on matching vendors
    3. Generate summary: count of newly flagged, count already flagged, count cleared
    4. Send email to NotifyEmail using D365FO email template engine (SysEmailTable)

**Email summary content**
  Subject : "Dormant vendor review — [Month Year]"
  Body    : Newly dormant: N vendors | Previously dormant: N | Cleared this month: N
            Attachment: list of newly dormant vendors (VendAccount, VendName, LastTransDate)

**Developer hand-off**
  - New boolean field CompanyDormantFlag on VendTable.CompanyModel
  - Batch class CompanyVendDormantBatch (SysOperation, ReliableAsynchronous)
  - DataContract parameters: InactivityMonths (int, default 18), NotifyEmail (str)
  - Email template: create SysEmailTable record "VendDormantSummary"
  - Schedule: add to Batch job form by admin after deployment
```

---

## Requirement 12 — Standard report or new? Spec the right answer for the client

### Business requirement (from SFD)

> Workshop with the procurement manager:
> "When we send purchase order confirmations to suppliers, we want our company logo
>  and the customs clearance reference field we added (Requirement 1) to appear on the
>  printed document. Is this the standard PO confirmation report or a new one?
>  The client wants to know if this is a small change or a big build."

### Cowork prompts used

**Step 1 — Find the standard report:**
> What is the standard D365FO report used to print purchase order confirmations?
> Is it part of print management?

**Step 2 — Check what data it already has:**
> Does the PO confirmation report already include the PurchTable data source?
> Can the customs clearance reference field (stored on PurchTable) be added without
> restructuring the report?

**Step 3 — Estimate complexity for the client:**
> Is extending an existing print management report considered a low, medium, or high
> complexity change in D365FO? What does the developer need to do?

### Technical spec section produced

```
## Technical Design — Purchase order confirmation printout extension

**Standard report found**
  Report: PurchPurchaseOrder
  Type  : Print management report (replaces via PrintMgmtDocType::PurchPO)
  Used  : Automatically when "Confirm" is posted on a purchase order

  → This IS the standard report. No new report needed.

**Data availability**
  PurchTable is already a source in the report query.
  CustomsClearanceRef field (added in Req 1 to PurchTable) is accessible.
  → The field CAN be added to the printout without structural changes.

**Change size assessment for client**
  Complexity: LOW-MEDIUM
  - Adding a field to a print management report requires a code extension (not config-only)
  - Standard approach: extend the report data provider class + temp table + report design
  - No report replacement — existing print management routing and PDF archiving preserved
  - Logo: handled via Print management document settings (configuration, no code)

**SFD statement for client**
  "The standard D365FO purchase order confirmation report (PurchPurchaseOrder) will be
   extended to include the customs clearance reference field. Logo is configured via
   Print management settings. This is a low-medium complexity extension — no new report
   is created and the existing print routing is preserved."

**Developer hand-off**
  - Extend PurchPurchaseOrderTmp (temp table) with CustomsClearanceRef field
  - Extend PurchPurchaseOrderDP.processReport() to populate the new field from PurchTable
  - Update SSRS report design to add the field to the document layout
  - Logo: client IT admin configures via Organization administration >
    Print management > PurchPurchaseOrder > Logo setting (no dev work)
```

---

## Requirement 13 — Pre-sign-off ISV conflict check

### Business requirement (from SFD)

> Before the SFD sign-off meeting, the client's IT director asks:
> "We already have the FreightISV solution installed. You're recommending we add a new
>  customization layer on top. Before I approve this, I want to know: will the new
>  customizations conflict with what FreightISV has already extended?
>  Can you put that risk assessment in the SFD?"

### Cowork prompts used

**Step 1 — Understand the ISV footprint:**
> List all objects in FreightISV model — how many tables, classes, forms, and extensions does it contain?
> What standard objects has it extended?

**Step 2 — Check overlap with planned customizations:**
> Our new customizations will touch PurchTable, VendTable, and LedgerJournalTrans.
> Has FreightISV already extended any of these tables or forms?
> Are there CoC extensions or event handlers from FreightISV on those objects?

**Step 3 — Name the risks:**
> If both FreightISV and our new model extend PurchTable.validateWrite() with CoC,
> is that a conflict? What should I tell the client?

### Technical spec section produced

```
## Technical Design — ISV conflict risk assessment (FreightISV)

**FreightISV footprint (from model stats)**
  Tables     : 12 new, 8 extensions
  Classes    : 34 new, 6 extensions
  Forms      : 3 new, 5 extensions
  Data entities: 4 public

**Overlap check: planned customization objects**

  Object                     FreightISV extension?   Type              Risk
  ─────────────────────────────────────────────────────────────────────────
  PurchTable                 YES — table extension   Field additions   LOW
                             YES — CoC on post()     Logic             MEDIUM
  VendTable                  NO                      —                 NONE
  LedgerJournalTrans         NO                      —                 NONE
  PurchTable.validateWrite() YES — CoC extension     Validation logic  MEDIUM

**Risk detail: PurchTable.validateWrite() CoC conflict**
  FreightISV extends validateWrite() to check freight routing.
  Our new customization will extend validateWrite() to validate CustomsClearanceRef.
  CoC chains — both extensions run in sequence. This is NOT a hard conflict.
  Risk: if FreightISV's CoC throws an exception early, ours may not run.
  Mitigation: developer must review the FreightISV extension and ensure call to next::validateWrite()
  is not conditionally skipped.

**SFD risk statement for client**
  "FreightISV and the planned customizations share one CoC extension point
   (PurchTable.validateWrite). This is a low-risk co-existence scenario — D365FO
   supports multiple CoC extensions on the same method. The developer will review
   the FreightISV extension during implementation to confirm correct chaining order.
   No other conflicts detected across VendTable and LedgerJournalTrans."

**Developer hand-off**
  - Before implementing PurchTable CoC: review FreightISV extension source
    (find_coc_extensions("PurchTable", "validateWrite"))
  - Coordinate with FreightISV support if chaining order is critical
  - All other planned objects: no ISV overlap, proceed without restriction
```

## Chaining prompts in a single Cowork session

For large SFDs, you can run a multi-requirement enrichment in one session.
Paste the full requirements block and frame it like this:

```
I just came out of a workshop and captured the following business requirements
in my SFD. For each one, add the technical D365FO design: table/field names,
EDTs, extension patterns, affected classes, security objects, and labels.
Format each as a "Technical Design" section I can paste directly into my SFD.

--- REQUIREMENTS ---

REQ-01: [paste requirement text]
REQ-02: [paste requirement text]
REQ-03: [paste requirement text]
```

Cowork will process each requirement through the appropriate skill, call the metadata
tools in sequence, and return a complete Technical Design block per requirement.
You paste those blocks into your SFD, then hand the full document to the MCP X++ Dev
agent or CLI Cloud Agent to generate the X++ code.

---

## Tips for better SFD enrichment

- **Include the business object name** if you know it ("purchase order", "vendor", "sales line")
  — the plugin maps it to the right D365FO table faster.
- **State what the user is trying to do** ("view", "import", "approve", "filter", "print")
  — determines which skill and tool combination applies.
- **Ask label deduplication before every new field** — it takes 10 seconds and prevents
  creating redundant labels that accumulate across models.
- **Always ask for the CoC footprint** on any class you plan to extend — knowing existing
  extensions avoids chain conflicts and upgrade surprises.
- **Close the loop with the Dev Agent prompt** — each Technical Design section ends with
  a ready-to-paste prompt for the MCP X++ Dev agent so development can start immediately.
