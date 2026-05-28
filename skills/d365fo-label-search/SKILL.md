---
name: d365fo-label-search
description: >
  Use when user asks about D365FO labels or wants to find existing labels before creating new ones.
  "existing label for approval status", "label that means invoice date",
  "before I create a label check if one exists for", "find label containing invoice",
  "avoid creating duplicate label", "what label ID should I use for customer account",
  "search labels for vendor payment", "reuse existing label for approval workflow",
  "what is the en-US text for label @SYS12345"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Label Search

Search the D365FO label index to find existing labels before creating new ones,
preventing duplication and ensuring consistency with standard D365FO terminology.

## When to use

- User wants to reuse an existing label rather than create a new one
- User asks which label ID to reference in a new field, control, or message
- User wants to find all labels related to a concept (e.g., all labels containing "invoice")
- User needs the en-US text for a known label ID (reverse lookup)
- User is performing a label audit before a customization

## Workflow

1. **Extract the concept** from the user's question (e.g., `"approval status"`, `"invoice date"`).

2. **Generate synonym queries.** Identify 2-3 variations to maximize recall:
   - Exact phrase: `"approval status"`
   - Shorter noun: `"approval"`
   - Alternative phrasing: `"workflow status"`

3. **Search.** Call `search_labels(query)` for each variation — returns label ID, text,
   label file name, and module.

4. **Get details.** Call `get_label_info(labelId)` on the top 3 candidates to get translations
   and the full context (label file path, module, usage count if available).

5. **Recommend:**
   - If an exact or very close match exists: suggest reuse with the label ID and usage example.
   - If only partial matches exist: show them and explain the difference from what the user needs.
   - If no match: confirm the user should create a new label and suggest the appropriate label
     file based on their model.

## Output Format

### Label search results

| Label ID | Text (en-US) | Label File | Module | Match Quality |
|---|---|---|---|---|
| @SYS12345 | Approval status | SYS | SystemFoundation | Exact |
| @SYS67890 | Approved | SYS | SystemFoundation | Partial |
| @WHS4321 | Approval Status | WHS | WHSMobile | Exact (different module) |

### Recommendation block

When reusing an existing label:
> **Reuse `@SYS12345`** (text: "Approval status")
> - In X++: `"@SYS12345"`
> - In XML metadata: `Label="@SYS12345"`
> - Available in: all environments (SYS label file)

When creating a new label:
> **Create a new label** in your model's label file (`YourModel_en-US.label.txt`).
> Suggested format: `@YOURPREFIX_NNN` (e.g., `@MYMOD_001`)

## Notes

- Always search with at least 2 variations before recommending a new label.
- Labels in `SYS`, `ApplicationPlatform`, and `ApplicationFoundation` are available in
  all D365FO environments regardless of license.
- Module-specific labels (e.g., `@WHS`, `@SCM`, `@PBA`) may be absent if that module is
  not licensed in the target environment.
- Label IDs are **case-sensitive** in X++: `"@SYS12345"` != `"@sys12345"`.
- Do not create labels in standard Microsoft label files — always use a label file in your
  own model.
