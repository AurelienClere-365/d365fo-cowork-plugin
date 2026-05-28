---
name: d365fo-model-architecture
description: >
  Use when user asks about D365FO model structure, dependencies, coupling, naming conventions, or impact analysis.
  "what models depend on ApplicationSuite", "show coupling metrics for our ISV layer",
  "which objects will be affected if I change SalesTable", "are there circular model dependencies",
  "validate naming convention for our custom model", "how many objects are in FleetManagement model",
  "analyze impact of adding a field to CustTable", "stats for all custom models"
license: MIT
metadata:
  version: "1.0"
---

# D365FO Model Architecture & Impact Analysis

Analyse model structure, dependency coupling, object counts, naming conventions, and
change impact before making architectural decisions or writing a technical spec.

## When to use

- User is evaluating the risk and blast radius of a change to a base object
- User wants to understand model dependency chains before adding a new model reference
- User is performing a code quality or coupling review of an ISV or custom model layer
- User wants to validate that new objects follow D365FO naming conventions
- User needs object counts and statistics for project estimation or documentation

## Workflow

1. **List all models.** Call `list_models()` — returns all indexed models with their
   publisher, layer, and whether they are custom vs. standard.

2. **Get model statistics.** Call `stats(model)` — returns object counts by type
   (tables, classes, forms, etc.) for a specific model or all custom models.

3. **Analyse dependencies.** Call `get_model_dependencies(modelName)` — returns
   `dependsOn` (what this model references) and `dependedBy` (what references it).

4. **Check coupling.** Call `models_coupling(topN, onlyCycles)` — returns fan-in,
   fan-out, instability, and detected dependency cycles across all models. Use
   `onlyCycles: true` to focus only on circular dependencies (these block upgrades).

5. **Analyse change impact.** Call `analyze_impact(target)` — given an object name,
   returns all objects that directly or transitively reference it, scoped to custom
   models. Use this before modifying a widely-used base class or table.

6. **Validate naming.** Call `validate_object_naming(name, type)` — checks the name
   against D365FO naming convention rules (prefix requirements, casing, reserved words).

7. **Run BP lint.** Call `lint(categories, onlyCustomModels: true)` — runs best-practice
   checks (missing indexes, EDT-less string fields, unnamed extensions) across custom
   models only.

8. **Multi-object search.** Call `batch_search(queries[])` — resolves multiple object
   names in a single call; useful for validating a list of objects from an SFD.

## Output Format

### Model dependency

```
FleetManagement
  dependsOn  : ApplicationSuite, ApplicationPlatform
  dependedBy : FleetManagementExtension, ContosoCustModel
```

### Coupling metrics

| Model | Fan-in | Fan-out | Instability | Cycles |
|---|---|---|---|---|
| ContosoCustModel | 0 | 5 | 1.00 (leaf) | None |
| ApplicationSuite | 312 | 8 | 0.03 (stable) | None |
| ISVModelA | 4 | 4 | 0.50 | ⚠ cycle with ISVModelB |

> **Instability** = fan-out / (fan-in + fan-out). 1.0 = leaf (nothing depends on it),
> 0.0 = core (everything depends on it). Custom models should target instability ≥ 0.8.

### Impact analysis

| Object affected | Type | Model | Reference path |
|---|---|---|---|
| SalesConfirmDP | Class | ContosoCustModel | CoC → SalesTable |
| ContosoSalesTableExt | TableExt | ContosoCustModel | TableExtension of SalesTable |

### BP lint findings

| Rule | Severity | Object | Detail |
|---|---|---|---|
| string-without-edt | Warning | ContosoSalesTableExt.MyField | str field has no EDT |
| table-no-index | Warning | ContosoTmpTable | No clustered index defined |

## Notes

- Run coupling analysis **before** adding a new `dependsOn` entry to a model — adding
  a dependency on a high fan-in model (instability near 0) makes your model harder to
  upgrade independently.
- `analyze_impact` scopes to the indexed metadata — it does not parse unindexed X++
  source. For very new customisations, re-run `d365fo index refresh` first.
- Circular model dependencies (`onlyCycles: true`) are blocked by the D365FO compiler
  and will cause build failures — resolve before committing.
- Naming convention: custom objects must be prefixed with your model's prefix
  (e.g. `Contoso`). `validate_object_naming` checks prefix, casing, and reserved words.