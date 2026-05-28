---
name: d365fo-business-events
description: >
  Use when user asks about D365FO business events, outbound notifications, or event-driven integrations.
  "does a business event exist for purchase order confirmation", "what payload does VendorInvoicePosted send",
  "find business events related to vendor invoices", "scaffold a custom business event for approval workflow",
  "list all business events in Procurement", "what contract class does PurchaseOrderConfirmed use",
  "trigger Power Automate on sales order confirmation", "outbound event when invoice is posted"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Business Events

Discover standard business events and scaffold custom ones. Business events are the
preferred mechanism for outbound event-driven integrations with Power Automate,
Logic Apps, Azure Service Bus, and third-party systems.

## When to use

- User needs an outbound trigger for an integration (Power Automate, Logic Apps, etc.)
- User wants to check if a standard business event exists before building a custom one
- User is documenting the event payload for an SFD integration specification
- User needs to scaffold a new custom business event class and contract

## Workflow

1. **Search for existing events.** Call `search_business_events(query)` with the business
   concept (e.g. "purchase order confirmed", "vendor invoice posted", "sales order").
   Filter by `category` if the module is known (e.g. "Procurement").

2. **Get event details.** Call `get_business_event(eventName)` — returns the contract class,
   event category, and the payload fields exposed.

3. **Recommend standard vs. custom.**
   - Standard event found → document it: name, contract class, payload, and how to
     subscribe in Power Automate (System administration > Business events > Business
     event catalog).
   - No standard event → recommend a custom business event and scaffold it:
     Call `generate_business_event(name, contractName, category)` — returns XML
     skeletons for the event class and contract class ready to paste into a D365FO project.

4. **Document the payload** using the Output Format table.

## Output Format

### Standard event

| Property | Value |
|---|---|
| Event name | PurchaseOrderConfirmedBusinessEvent |
| Category | Procurement and sourcing |
| Contract class | PurchaseOrderConfirmedContract |
| Trigger point | PurchFormletterPurchOrderJournalize::post() |

### Payload fields

| Field | Type | Description |
|---|---|---|
| PurchId | str | Purchase order number |
| VendAccount | str | Vendor account number |
| CurrencyCode | str | Transaction currency |
| TotalAmount | Real | Order total in transaction currency |
| ConfirmationDate | Date | Confirmation date |

### Custom event scaffold (from generate_business_event)

The tool returns two XML files:
- `<EventName>.xml` — the business event class implementing `BusinessEventsBase`
- `<ContractName>.xml` — the data contract class with `[DataContract]` and `[DataMember]` attributes

Add both to your D365FO project, register the event in `BusinessEventsFactory`, and build.

## Notes

- Business events require the **Business events** feature to be enabled in Feature management.
- Standard business events are read-only — extend via a custom business event that publishes
  alongside the standard one, or use an event handler on the standard event's `send()` method.
- Payload fields must be serializable (str, int, real, date, utcdatetime) — no complex objects.
- For Dataverse integration, prefer **Virtual Entities** or **Dual-write** over business events.