---
name: d365fo-integration-services
description: >
  Use when user asks about D365FO integrations, OData entities, custom services, service groups, or the full integration surface.
  "what OData entities are available for vendor invoices", "find the custom service for sales order creation",
  "report all integration points in model FleetManagement", "service group for DMF", "what SOAP services exist",
  "integration surface for procurement module", "which service exposes PurchTable", "enumerate all business events and batch jobs"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Integration Services

Map the full integration surface of a D365FO environment or model — OData entities,
custom SOAP/JSON services, service groups, business events, and batch jobs — to design
or document an integration specification.

## When to use

- User is writing an integration SFD and needs to know which D365FO endpoints exist
- User wants to find an existing OData entity or service before building a custom one
- User needs the WSDL / endpoint metadata for a custom service
- User is auditing all integration touchpoints in a specific ISV or custom model
- User wants to compare inbound (service, entity) vs. outbound (business event) options

## Workflow

1. **Get the full integration report.** Call `report_integrations()` (optionally with
   `model` to scope to one model) — returns counts and names across:
   - OData entities (`AxDataEntity` with `IsPublic = Yes`)
   - Custom services (`AxService`)
   - Service groups (`AxServiceGroup`)
   - Business events
   - Workflow types
   - Batch jobs

2. **Drill into a service.** Call `get_service(serviceName)` — returns operations,
   request/response contract classes, and the service group it belongs to.

3. **Drill into a service group.** Call `get_service_group(groupName)` — returns
   member services and the endpoint URL pattern.

4. **Analyze integration design.** Call `analyze_integration(target)` to get a
   recommendation on the best integration pattern for the described scenario
   (OData CRUD, custom service call, business event subscription, DMF package,
   or Dual-write).

5. **Present a summary table** per the Output Format.

## Output Format

### Integration surface summary

| Category | Count | Notes |
|---|---|---|
| OData entities (public) | 847 | Consumable via `/data/<EntityName>` |
| Custom services | 23 | SOAP endpoint: `/soap/services/<GroupName>` |
| Service groups | 8 | Groups related services into one endpoint |
| Business events | 312 | Subscribe in Business event catalog |
| Workflow types | 45 | Trigger via workflow engine |
| Batch jobs | 130 | Scheduled via Batch job form |

### Service detail

| Property | Value |
|---|---|
| Service name | SalesOrderService |
| Group | SalesOrderServiceGroup |
| Operations | create, read, update, delete |
| Request contract | SalesOrderServiceRequest |
| Response contract | SalesOrderServiceResponse |
| Endpoint | `/soap/services/SalesOrderServiceGroup` |

### Integration pattern recommendation

| Scenario | Recommended pattern | Reason |
|---|---|---|
| Import vendor invoices from EDI | DMF data entity | Bulk, asynchronous, retry support |
| Real-time PO status to ERP | OData entity + polling or business event | Event-driven preferred |
| Custom approval callback | Custom JSON service | Synchronous, complex logic |

## Notes

- **OData** is the default inbound pattern for CRUD operations — check for a public
  data entity before building a custom service.
- **Custom services** (SOAP and JSON) are for complex transactional operations not
  covered by OData (e.g. multi-step posting).
- **Business events** are for outbound notifications — never for inbound data submission.
- **DMF (Data Management Framework)** is for bulk imports/exports using data entities.
- Dual-write and Virtual Entities are the preferred patterns for Dataverse/Power Platform
  integration — only use custom services as a last resort in that scenario.