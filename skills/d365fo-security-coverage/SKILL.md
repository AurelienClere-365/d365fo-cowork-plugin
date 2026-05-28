---
name: d365fo-security-coverage
description: >
  Use when user asks about D365FO security, access rights, privileges, duties, or roles.
  "which privilege allows creating vendor payment journals", "which role has access to PurchTable",
  "security coverage for LedgerJournalTable", "who can post to vendor invoice journal",
  "access to Accounts Payable menu item", "least privilege for vendor invoice posting",
  "what roles include duty VendPaymentJournalMaintain", "security audit for table VendTrans",
  "which roles can read SalesTable"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Security Coverage

Trace D365FO security from a table or menu item through the full privilege -> duty -> role
hierarchy. Supports security audits, Segregation of Duties (SoD) reviews, and access
requirement documentation.

## When to use

- User needs to know which privilege, duty, or role grants access to a table or menu item
- User is performing a security audit or preparing an SoD review
- User wants to find the least-privilege role for a specific access requirement
- User is documenting security requirements for a new customization or report
- User wants to understand which roles a user must have to perform a specific action

## Workflow

1. **Identify the object.** Extract the table name, menu item name, or form name from the
   question.

2. **Get coverage.** Call `get_security_coverage_for_object(objectName)` — returns all
   privileges that reference this object, along with the access level granted
   (Read, Update, Create, Delete, FullControl).

3. **Filter by access level.** Keep only privileges that match the user's intent
   (e.g., Create + Update for "can post", Read for "can view").

4. **Get privilege details.** Call `get_security_privilege(privilegeName)` for each relevant
   privilege — returns permissions granted and which duties include it.

5. **Get duty details.** Call `get_security_duty(dutyName)` — returns which roles include
   this duty.

6. **Get role details.** Call `get_security_role(roleName)` for additional role context if
   the user needs role descriptions or role member lists.

7. **Present as hierarchy** (see Output Format).

## Output Format

### Security hierarchy (text)

```
Object: LedgerJournalTable (access: Create, Update, FullControl)

  Privilege: LedgerJournalizeVendPaymentProcess (FullControl)
    Duty: VendPaymentJournalMaintain
      Role: AccountsPayablePaymentsClerk
      Role: AccountsPayableManager

  Privilege: VendPaymentJournalView (Read)
    Duty: VendPaymentJournalInquire
      Role: AccountsPayableClerk
```

### Tabular summary

| Object | Privilege | Access Level | Duty | Role |
|---|---|---|---|---|
| LedgerJournalTable | LedgerJournalizeVendPaymentProcess | FullControl | VendPaymentJournalMaintain | AccountsPayablePaymentsClerk |

## Notes

- Standard D365FO uses a 4-layer model: **Object -> Privilege -> Duty -> Role**. Present
  all 4 layers for a complete answer.
- If `get_security_coverage_for_object` returns many privileges, group them by access level
  (FullControl, Create/Update, Read) so the user can choose the least-privilege option.
- For SoD analysis, note when the same role appears under duties with conflicting access
  (e.g., both "create vendor invoice" and "approve vendor invoice").
- The `SystemAdministrator` role covers almost everything — exclude it unless the user
  specifically asks about sysadmin access.
