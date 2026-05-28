---
name: d365fo-extension-strategy
description: >
  Use when user asks how to extend or customize D365FO without overlayering base code.
  "how to extend VendTable without overlayering", "best way to add a field to SalesTable",
  "can I use CoC for PurchFormLetter", "extension point for SalesLine validation",
  "how to add logic when a customer is saved", "modify behavior of CustPostInvoice class",
  "extend a form without touching base objects", "what extension strategy should I use",
  "difference between CoC and event handler"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Extension Strategy

Recommend the correct extension pattern for D365FO customizations that avoid overlayering.
This is a prompt-only skill — it does not call MCP tools but applies D365FO extension
best practices directly.

## When to use

- User wants to add custom fields, logic, or UI to a standard D365FO object
- User asks which extension API to use (CoC, Event Handler, Table Extension, Form Extension)
- User asks whether a specific class or table supports a particular extension type
- User needs an X++ code skeleton to start from
- User asks about the difference between CoC and Data Event Handlers

## Workflow (prompt-only — no MCP tools required)

1. **Understand what the user needs to change:**
   - Add a **field** -> Table Extension
   - Add a **UI control** -> Form Extension
   - Override **method behavior** -> Chain of Command (CoC)
   - React to **data events** (insert / update / delete) -> Data Event Handler or CoC on table
   - Add a **menu item** -> New Action Menu Item + new class or form
   - Extend **security** -> Security Extension (Privilege/Duty)

2. **Apply the decision guide** (see below).

3. **Provide a code skeleton** from [references/extension-patterns.md](references/extension-patterns.md).

4. **Flag constraints** for the chosen pattern (e.g., CoC requires `next`, table extensions
   cannot change existing field types).

5. **Recommend using `find_coc_extensions`** (via the `d365fo-class-analysis` skill) to
   check whether another extension already wraps the same method before creating a new one.

## Decision Guide

| Scenario | Recommended Pattern | Key Constraint |
|---|---|---|
| Add custom field | Table Extension | Cannot change existing field base types |
| Override class method | Chain of Command | Must call `next` — class must support CoC |
| React to table insert/update | CoC on table OR Data Event Handler | Event Handler = post-commit, no rollback |
| Intercept and change return value | Chain of Command only | Event Handlers cannot modify return values |
| Add form control | Form Extension + event handler | Cannot reorder existing controls |
| Add menu item to existing menu | Menu Extension | New class or form required |
| Restrict/grant access to new field | Security Extension (Privilege) | Must wire to a Duty and a Role |
| Cross-model loose coupling | Data Event Handler | Runs after commit — cannot be cancelled |

## Code Skeleton: CoC on a class method

```x++
[ExtensionOf(classStr(TargetClass))]
final class TargetClass_YourModel_Extension
{
    public ReturnType methodName(ParamType param)
    {
        // Code here runs BEFORE the original method (pre-processing)

        ReturnType result = next methodName(param);   // calls the original (required)

        // Code here runs AFTER the original method (post-processing)

        return result;
    }
}
```

## Code Skeleton: Data Event Handler

```x++
[DataEventHandler(tableStr(SalesTable), DataEventType::Inserted)]
public static void SalesTable_onInserted(Common _record, DataEventArgs _eventArgs)
{
    SalesTable salesTable = _record as SalesTable;
    // Runs after every SalesTable.insert() — post-commit, cannot rollback
}
```

See [references/extension-patterns.md](references/extension-patterns.md) for full skeletons
covering table extensions, form extensions, and security extensions.

## Notes

- **Never overlayer** objects outside your own model. All changes must be extensions.
- **CoC > Event Handler** when you need to intercept and modify behavior or parameters.
- **Event Handler > CoC** when you need loose coupling or only need to react post-commit.
- Always check for existing CoC extensions (via `d365fo-class-analysis`) before writing a
  new one — conflicting `next` chains cause hard-to-debug runtime issues.
