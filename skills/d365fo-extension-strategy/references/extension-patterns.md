# D365FO Extension Patterns

X++ skeleton templates for common D365FO extension scenarios.
All patterns follow the no-overlayer rule: customizations live in extension objects
within your own model and never modify standard Microsoft objects directly.

---

## Pattern 1: Chain of Command (CoC) on a class method

**Use when:** you need to add logic before or after an existing class method, or when you
need to intercept and modify the return value or parameters.

```x++
[ExtensionOf(classStr(TargetClass))]
final class TargetClass_YourModel_Extension
{
    public ReturnType methodName(ParamType param)
    {
        // Pre-processing (runs before the original)

        ReturnType result = next methodName(param);   // calls the original — required

        // Post-processing (runs after the original)

        return result;
    }
}
```

**Rules:**
- The extension class MUST be `final`.
- You MUST call `next methodName(...)` — omitting it breaks the entire CoC chain.
- Use `[ExtensionOf(classStr(...))]` for classes or `[ExtensionOf(tableStr(...))]` for tables.
- Naming convention: `OriginalClass_YourModelName_Extension`.

---

## Pattern 2: CoC on a table method (insert / update / delete)

**Use when:** you need to run logic when records are saved or deleted.

```x++
[ExtensionOf(tableStr(VendTable))]
final class VendTable_YourModel_Extension
{
    public void insert()
    {
        next insert();     // always call next FIRST for insert and update

        // Post-insert logic (record is now in database)
        if (this.YourCustomField)
        {
            // ...
        }
    }

    public void update()
    {
        // Pre-update logic (record not yet saved)

        next update();

        // Post-update logic
    }

    public boolean validateWrite()
    {
        boolean ret = next validateWrite();

        if (ret && this.YourCustomField == "")
        {
            ret = checkFailed("Your custom field is required.");
        }

        return ret;
    }
}
```

---

## Pattern 3: Table extension (add custom fields)

Create a new object of type **Table Extension** in your model, targeting the base table.
Extension name convention: `BaseTable.YourModel` (e.g., `VendTable.MyCompanyModel`).

**What you can do:**
- Add new fields
- Add new indexes
- Add fields to existing field groups
- Create new field groups
- Add relations

**What you cannot do:**
- Remove or rename existing fields
- Change the base type of existing fields
- Remove existing indexes

After adding a field named `MyCustomField` (EDT: `MyCustomEDT`), access it in X++:
```x++
VendTable vendTable = VendTable::find(accountNum);
vendTable.MyCustomField = "value";
vendTable.update();
```

---

## Pattern 4: Form extension (add controls / event handlers)

Create a **Form Extension** object in your model targeting the base form.

```x++
// Event handler class for a new button added via form extension
[FormControlEventHandler(formControlStr(VendTable, MyCustomButton), FormControlEventType::Clicked)]
public static void MyCustomButton_OnClicked(FormControl _sender, FormControlEventArgs _e)
{
    FormRun formRun = _sender.formRun() as FormRun;
    VendTable vendTable = formRun.dataSource(formDataSourceStr(VendTable, VendTable)).cursor();

    // Act on the current record
    info(strFmt("Selected vendor: %1", vendTable.AccountNum));
}
```

Access a data source field in a form event handler:
```x++
[FormDataFieldEventHandler(formDataFieldStr(VendTable, VendTable, Name), FormDataFieldEventType::Modified)]
public static void VendTable_Name_OnModified(FormDataObject _dataObject, FormDataFieldEventArgs _e)
{
    // Fired when the Name field is modified in the form
}
```

---

## Pattern 5: Data Event Handler (loosely-coupled table events)

**Use when:** you need to react to table events (insert / update / delete) without tight
coupling to the calling code path. Runs post-commit — cannot roll back the transaction.

```x++
[DataEventHandler(tableStr(SalesTable), DataEventType::Inserted)]
public static void SalesTable_onInserted(Common _record, DataEventArgs _eventArgs)
{
    SalesTable salesTable = _record as SalesTable;
    // Access fields: salesTable.SalesId, salesTable.CustAccount, etc.
}

[DataEventHandler(tableStr(SalesTable), DataEventType::Updated)]
public static void SalesTable_onUpdated(Common _record, DataEventArgs _eventArgs)
{
    SalesTable salesTable = _record as SalesTable;
}

[DataEventHandler(tableStr(SalesTable), DataEventType::Deleted)]
public static void SalesTable_onDeleted(Common _record, DataEventArgs _eventArgs)
{
    SalesTable salesTable = _record as SalesTable;
}
```

---

## Pattern 6: Security extension (add privilege)

Add a new `Privilege` object to your model granting access to your extension objects.

```xml
<!-- In your model's security/Privileges folder -->
<!-- Privilege: MyModel_VendTableCustomFieldMaintain -->
<AxSecurityPrivilege>
  <Name>MyModel_VendTableCustomFieldMaintain</Name>
  <Label>Maintain custom vendor fields</Label>
  <Permissions>
    <AxSecurityTablePermission>
      <ManagedBy>Manual</ManagedBy>
      <PermissionObject>VendTable</PermissionObject>
      <Read>Allow</Read>
      <Update>Allow</Update>
    </AxSecurityTablePermission>
  </Permissions>
</AxSecurityPrivilege>
```

Wire the privilege into an existing Duty via a **Security Duty Extension** in your model,
then the duty will flow to all roles that already include it.

---

## When to use each pattern — quick reference

| Need | Pattern | Notes |
|---|---|---|
| Add a custom field | Table Extension | Cannot change existing field types |
| Override method and modify return value | CoC on class | Must call `next` |
| Run logic on table save | CoC on table `insert`/`update` | Call `next` first for insert/update |
| Validate before save | CoC on `validateWrite` | Return false to block save |
| React to save (loose coupling) | Data Event Handler | Post-commit, cannot cancel |
| Add form button or control | Form Extension | Use event handler attribute |
| Grant access to new objects | Security Privilege | Wire to existing Duty |
