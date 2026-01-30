# Bepoz Custom Fields Manager - Enhanced Edition

## Overview
Complete GUI tool for managing custom field **definitions** and **values** across 7 core Bepoz database tables. Provides friendly field naming, data entry, and centralized field management.

---

## What's New in Enhanced Edition

### ✅ Corrected Field Type Mapping
- **Flag** = CustomFieldType 0 (was 1)
- **Date** = CustomFieldType 1 (was 4)
- **Number** = CustomFieldType 2 (unchanged)
- **Text** = CustomFieldType 3 (unchanged)

### ✅ Corrected Table ID Mapping
- **Account** = CustomTableID 0 (was 1)
- **Product** = CustomTableID 1 (was 3)
- **Operator** = CustomTableID 2 (unchanged)
- **Supplier** = CustomTableID 3 (NEW - added support)
- **Store** = CustomTableID 5 (was 5)
- **Venue** = CustomTableID 7 (unchanged)
- **Workstation** = CustomTableID 8 (unchanged)

### ✅ New Supplier Support
Full custom field support for dbo.Supplier table with SupplierID primary key.

### ✅ Field Name Manager Tab
New "⚙ Manage Field Names" tab for:
- **View** all CustomField definitions by table
- **Add** new field name definitions
- **Edit** existing field names
- **Delete** field definitions (with confirmation)

### ✅ Safety Features: Impact Analysis
**NEW** Before renaming or deleting field definitions:
- **Usage Check**: Automatically scans data table to count records using the field
- **Impact Preview**: Shows affected records (up to 100 samples) in DataGridView
- **Smart Detection**: 
  - Flags: Checks for TRUE values
  - Dates: Checks for non-NULL dates
  - Numbers: Checks for non-zero values
  - Text: Checks for non-empty strings
- **User Confirmation**: Must explicitly proceed or cancel after seeing impact
- **Color-Coded Warnings**: Green (safe) or Red (caution) based on usage

---

## How It Works

### Two-Step Process

**Step 1: Define Field Names** (Manage Field Names tab)
1. Select table (Account, Operator, Product, Supplier, Store, Venue, Workstation)
2. Click "Load Fields" to see existing definitions
3. To add new definition:
   - Select Field Type (Flag/Date/Number/Text)
   - Select Field Number (1-10 for Flag/Text, 1-5 for Date/Number)
   - Enter friendly name (e.g., "WiFi SSID", "Fire Code Capacity")
   - Click "Add"
4. To edit existing name:
   - Select row in grid
   - Modify name in textbox
   - Click "Save"
5. To delete definition:
   - Select row in grid
   - Click "Delete Selected"

**Step 2: Edit Field Values** (Data tabs: Venue, Store, etc.)
1. Select record from dropdown
2. Click "Load Fields"
3. Edit values using appropriate controls:
   - Flags → Checkboxes
   - Dates → Date/time pickers
   - Numbers → Numeric textboxes
   - Text → Text textboxes (max 8000 chars)
4. Click "Save Changes"

---

## Safety Features (NEW)

### Impact Analysis Before Rename/Delete

Before renaming or deleting a field definition, the tool automatically checks if any records are currently using that field and shows you the impact.

#### What Gets Checked
- **Flag fields**: Records where value = TRUE (1)
- **Date fields**: Records where date is NOT NULL
- **Number fields**: Records where value ≠ 0
- **Text fields**: Records where text is NOT empty

#### Impact Preview Dialog Shows:
1. **Usage Count**: "47 record(s) have data in this field"
2. **Field Details**: Name, Table, Column
3. **Affected Records**: DataGridView showing up to 100 sample records with:
   - Primary Key (e.g., AccountID, ProductID)
   - Record Name
   - Current field value
4. **Color-Coded Warning**:
   - 🟢 **Green**: "This field is NOT in use - safe to proceed"
   - 🔴 **Red**: "WARNING: This field is currently in use!"

#### User Decision Required
You must explicitly confirm:
- **Proceed with Update/Delete** - Applies the change despite usage
- **Cancel** - Aborts the operation

#### Example Scenario
You want to rename **AccountFlag1** from "Active" to "Passed Probation":

```
┌──────────────────────────────────────────────────┐
│ Custom Field Usage - Update Confirmation        │
├──────────────────────────────────────────────────┤
│ ⚠️ WARNING: This field is currently in use!      │
│ 47 record(s) have data in this field.           │
│                                                  │
│ Field Name: Active                               │
│ Table: dbo.Account                               │
│ Column: CustomFlag_1                             │
│                                                  │
│ Affected Records (showing first 100):            │
│ ┌───────────┬─────────────┬──────────────┐      │
│ │ AccountID │ Name        │ CustomFlag_1 │      │
│ ├───────────┼─────────────┼──────────────┤      │
│ │ 1001      │ John Smith  │ True         │      │
│ │ 1005      │ Sarah Jones │ True         │      │
│ │ 1023      │ Mike Wilson │ True         │      │
│ └───────────┴─────────────┴──────────────┘      │
│                                                  │
│    [Proceed with Update]  [Cancel]              │
└──────────────────────────────────────────────────┘
```

#### Safety Benefits
- ✅ **Prevents accidental changes** to actively-used fields
- ✅ **Shows impact** before you commit
- ✅ **Identifies which records** will be affected
- ✅ **Allows informed decisions** about field management

---

## Field Name Definition Examples

### Example 1: WiFi Configuration (Venue)
```
Table: Venue
Field Type: Text, Field #: 1, Name: "WiFi SSID"
Field Type: Text, Field #: 2, Name: "WiFi Password"
Field Type: Flag, Field #: 1, Name: "WiFi Enabled"
```

**Result in Venue tab:**
- WiFi SSID (text field)
- WiFi Password (text field)
- WiFi Enabled (checkbox)

### Example 2: Fire Safety (Store)
```
Table: Store
Field Type: Number, Field #: 1, Name: "Fire Code Capacity"
Field Type: Number, Field #: 2, Name: "Current Occupancy"
Field Type: Flag, Field #: 1, Name: "Fire Inspection Current"
```

**Result in Store tab:**
- Fire Code Capacity (numeric field)
- Current Occupancy (numeric field)
- Fire Inspection Current (checkbox)

### Example 3: Product Online Availability
```
Table: Product
Field Type: Flag, Field #: 1, Name: "Available Online"
Field Type: Date, Field #: 1, Name: "Online Launch Date"
Field Type: Text, Field #: 1, Name: "Online Description"
```

**Result in Product tab:**
- Available Online (checkbox)
- Online Launch Date (date picker)
- Online Description (text field)

### Example 4: Operator Certifications
```
Table: Operator
Field Type: Date, Field #: 1, Name: "Food Safety Cert Expiry"
Field Type: Date, Field #: 2, Name: "Alcohol Service Cert Expiry"
Field Type: Flag, Field #: 1, Name: "All Certs Current"
```

**Result in Operator tab:**
- Food Safety Cert Expiry (date picker)
- Alcohol Service Cert Expiry (date picker)
- All Certs Current (checkbox)

### Example 5: Supplier Contacts
```
Table: Supplier
Field Type: Text, Field #: 1, Name: "Primary Contact Name"
Field Type: Text, Field #: 2, Name: "Primary Contact Email"
Field Type: Text, Field #: 3, Name: "Primary Contact Phone"
Field Type: Flag, Field #: 1, Name: "Active Supplier"
```

**Result in Supplier tab:**
- Primary Contact Name (text field)
- Primary Contact Email (text field)
- Primary Contact Phone (text field)
- Active Supplier (checkbox)

---

## Database Tables & Field Counts

### Supported Tables (7 total)
Each table supports **30 custom fields**:
- 10× CustomFlag_1..10 (bit) - Boolean checkboxes
- 5× CustomDate_1..5 (datetime) - Date/time pickers
- 5× CustomNum_1..5 (int) - Numeric textboxes
- 10× CustomText_1..10 (nvarchar 8000) - Text textboxes

**Total capacity:** 7 tables × 30 fields = **210 custom fields**

| Table | TableID | Primary Key | Display Column | Notes |
|-------|---------|-------------|----------------|-------|
| Account | 0 | AccountID | FirstName + LastName | TOP 100 limit |
| Product | 1 | ProductID | Name | TOP 100, excludes ProdType=1 |
| Operator | 2 | OperatorID | FirstName + LastName | All records |
| Supplier | 3 | SupplierID | Name | All records (NEW) |
| Store | 5 | StoreID | Name | All records |
| Venue | 7 | VenueID | Name | All records |
| Workstation | 8 | WorkstationID | Name | All records |

---

## Installation

### Prerequisites
- Windows PowerShell 5.1+
- .NET Framework 4.7.2+
- SQL Server access with Windows Integrated Security
- Bepoz registry configuration (HKCU:\SOFTWARE\Backoffice)

### Required Database Permissions
```sql
-- SELECT permissions (all users)
GRANT SELECT ON dbo.Venue TO [User];
GRANT SELECT ON dbo.Store TO [User];
GRANT SELECT ON dbo.Workstation TO [User];
GRANT SELECT ON dbo.Product TO [User];
GRANT SELECT ON dbo.Account TO [User];
GRANT SELECT ON dbo.Operator TO [User];
GRANT SELECT ON dbo.Supplier TO [User];
GRANT SELECT ON dbo.CustomField TO [User];

-- UPDATE permissions (for saving data)
GRANT UPDATE ON dbo.Venue TO [User];
GRANT UPDATE ON dbo.Store TO [User];
GRANT UPDATE ON dbo.Workstation TO [User];
GRANT UPDATE ON dbo.Product TO [User];
GRANT UPDATE ON dbo.Account TO [User];
GRANT UPDATE ON dbo.Operator TO [User];
GRANT UPDATE ON dbo.Supplier TO [User];

-- INSERT/DELETE permissions (for field name management)
GRANT INSERT, DELETE ON dbo.CustomField TO [User];
```

### Setup
1. Extract all files to folder (e.g., C:\Bepoz\CustomFieldsManager)
2. Double-click `RunCustomFieldsManager_Enhanced.bat`
3. Or run: `powershell.exe -ExecutionPolicy Bypass -File BepozCustomFieldsManager_Enhanced.ps1`

---

## GUI Tour

### Main Window
- **8 Tabs Total:**
  - ⚙ Manage Field Names (field definition management)
  - Venue, Store, Workstation, Product, Account, Operator, Supplier (data entry)
- **Status Bar:** Shows operation feedback
- **Close Button:** Exit application

### Manage Field Names Tab
**Top Section: View Definitions**
- Table dropdown → Select table to view
- Load Fields button → Display all definitions for table
- Grid → Shows Type, Field #, Technical Name, Friendly Name, Last Updated

**Bottom Section: Add/Edit Definitions**
- Field Type dropdown → Flag/Date/Number/Text
- Field # dropdown → 1-10 (Flag/Text) or 1-5 (Date/Number)
- Field Name textbox → Enter friendly name (max 50 chars)
- Add button → Create new definition
- Save button → Update selected definition
- Delete Selected button → Remove definition (data preserved)

### Data Entry Tabs (7 tabs)
**Each tab contains:**
- Record selector dropdown → Choose record to edit
- Load Fields button → Retrieve current custom field values
- Scrollable panel → 30 field editors with friendly names
- Save Changes button → Commit changes to database

---

## Workflow Examples

### Scenario 1: Setting Up WiFi Tracking for Venues

**Step 1: Define Field Names**
1. Open "⚙ Manage Field Names" tab
2. Select Table: "Venue"
3. Add definitions:
   - Type: Text, #: 1, Name: "WiFi SSID" → Click Add
   - Type: Text, #: 2, Name: "WiFi Password" → Click Add
   - Type: Flag, #: 1, Name: "WiFi Enabled" → Click Add

**Step 2: Enter Data**
1. Switch to "Venue" tab
2. Select venue: "1 - Main Restaurant"
3. Click "Load Fields"
4. Enter values:
   - WiFi SSID: "GuestNetwork"
   - WiFi Password: "Welcome2024"
   - WiFi Enabled: ✓ (checked)
5. Click "Save Changes"

**Result:** Venue 1 now has WiFi configuration stored in custom fields.

---

### Scenario 2: Tracking Supplier Contacts

**Step 1: Define Field Names**
1. "⚙ Manage Field Names" tab
2. Select Table: "Supplier"
3. Add definitions:
   - Type: Text, #: 1, Name: "Primary Contact Name"
   - Type: Text, #: 2, Name: "Contact Email"
   - Type: Text, #: 3, Name: "Contact Phone"
   - Type: Flag, #: 1, Name: "Active Supplier"

**Step 2: Enter Data**
1. "Supplier" tab
2. Select: "5 - ABC Food Distributors"
3. Load Fields
4. Enter:
   - Primary Contact Name: "John Smith"
   - Contact Email: "john@abcfood.com"
   - Contact Phone: "(555) 123-4567"
   - Active Supplier: ✓
5. Save Changes

---

### Scenario 3: Operator Certification Tracking

**Step 1: Define Field Names**
1. "⚙ Manage Field Names" tab
2. Table: "Operator"
3. Add:
   - Type: Date, #: 1, Name: "Food Handler Cert Expiry"
   - Type: Date, #: 2, Name: "Alcohol Service Cert Expiry"
   - Type: Flag, #: 1, Name: "Certs Current"

**Step 2: Enter Data**
1. "Operator" tab
2. Select operator
3. Load Fields
4. Set dates and checkbox
5. Save

---

## Technical Details

### Database Schema

**dbo.CustomField Structure:**
```sql
CREATE TABLE dbo.CustomField (
    CustomTableID int NOT NULL,      -- 0-8 (table identifier)
    CustomFieldType int NOT NULL,    -- 0-3 (field type)
    CustomFieldNum int NOT NULL,     -- 1-10 or 1-5 (field number)
    CustomOrderNum int NOT NULL,     -- Display order (-1 default)
    DateUpdated datetime NULL,       -- Last modified
    Name nvarchar(50) NOT NULL       -- Friendly name
)
```

**Custom Field Columns (All 7 Tables):**
```sql
-- Example: dbo.Venue (same pattern for all tables)
CustomFlag_1..CustomFlag_10 bit NOT NULL
CustomDate_1..CustomDate_5 datetime NULL
CustomNum_1..CustomNum_5 int NOT NULL
CustomText_1..CustomText_10 nvarchar(8000) NOT NULL
```

### CustomFieldType Mapping
| ID | Type | Control | SQL Type | Count |
|----|------|---------|----------|-------|
| 0 | Flag | Checkbox | bit | 10 |
| 1 | Date | DateTimePicker | datetime | 5 |
| 2 | Number | TextBox (numeric) | int | 5 |
| 3 | Text | TextBox (text) | nvarchar(8000) | 10 |

### CustomTableID Mapping
| ID | Table | Primary Key | Records Loaded |
|----|-------|-------------|----------------|
| 0 | Account | AccountID | TOP 100 |
| 1 | Product | ProductID | TOP 100 |
| 2 | Operator | OperatorID | All |
| 3 | Supplier | SupplierID | All |
| 5 | Store | StoreID | All |
| 7 | Venue | VenueID | All |
| 8 | Workstation | WorkstationID | All |

### Data Flow

**Loading Custom Fields:**
1. User selects record from dropdown
2. Click "Load Fields"
3. Query `dbo.CustomField` for friendly names (TableID match)
4. Query selected table for current values
5. Create 30 editor controls (10 flags, 5 dates, 5 numbers, 10 text)
6. Populate controls with current values
7. Enable "Save Changes" button

**Saving Custom Fields:**
1. User modifies field values
2. Click "Save Changes"
3. Extract values from all 30 controls
4. Convert types (checkbox→bit, textbox→int/nvarchar, datepicker→datetime)
5. Build parameterized UPDATE query with all 30 fields
6. Execute single UPDATE statement
7. Display success confirmation

**Managing Field Names:**
1. User selects table in "Manage Field Names" tab
2. Click "Load Fields"
3. Query `dbo.CustomField WHERE CustomTableID = @TableID`
4. Display in grid with friendly formatting
5. Add/Edit/Delete operations use INSERT/UPDATE/DELETE on dbo.CustomField
6. Field names immediately available in data tabs (reload to see changes)

---

## Troubleshooting

### Common Issues

**Issue: "Registry path not found"**
- **Cause:** HKCU:\SOFTWARE\Backoffice missing
- **Solution:** Verify Bepoz installed for current user, check SQL_Server and SQL_DSN values

**Issue: "Cannot connect to SQL Server"**
- **Cause:** SQL Server not running or Windows Auth failed
- **Solution:** Test connection in SSMS, verify SQL Server instance name in registry

**Issue: "No records found in dropdown"**
- **Cause:** Empty table or insufficient permissions
- **Solution:** Verify table has data, check SELECT permissions

**Issue: "Field definition already exists"**
- **Cause:** Attempting to add duplicate CustomField record
- **Solution:** Use "Save" button to update existing definition instead of "Add"

**Issue: "Field names not appearing"**
- **Cause:** No CustomField definitions exist
- **Solution:** Add definitions in "Manage Field Names" tab first

**Issue: "Cannot save numeric field"**
- **Cause:** Non-numeric characters entered
- **Solution:** Enter only digits (negative numbers allowed)

**Issue: "Text field truncated"**
- **Cause:** Exceeds 8000 character limit
- **Solution:** Shorten text to fit within limit

**Issue: "Error checking field usage"**
- **Cause:** Database connection lost or permissions issue during usage check
- **Solution:** Check console output for SQL error details, verify SELECT permissions on target table

**Issue: "Usage dialog shows incorrect count"**
- **Cause:** Mismatch between field definition and actual column usage
- **Solution:** Verify CustomFieldType and CustomFieldNum match the column being checked (e.g., CustomFlag_1 requires Type=0, Num=1)

**Issue: "Can't rename field despite showing 0 records"**
- **Cause:** Default values (FALSE for flags, 0 for numbers, empty for text) are not counted as "in use"
- **Solution:** This is by design - fields with only default values are safe to rename

---

## Security Features

### SQL Injection Prevention
- **All queries use parameterized commands**
- **User input NEVER concatenated into SQL strings**
- **Type-safe parameter conversion**

Example:
```powershell
$params = @{
    '@RecordID' = [int]$recordID
    '@CustomText_1' = [string]$textValue
}
Invoke-BepozNonQuery -Query $query -Parameters $params
```

### Data Validation
- **Numeric fields:** Validates integer parsing before save
- **Text fields:** Enforces 8000 character limit
- **Date fields:** Uses DateTimePicker (invalid dates prevented)
- **Flag fields:** Boolean only (checkbox)

### Audit Trail
- **CustomField.DateUpdated:** Tracks when field names modified
- **Console logging:** All database operations logged to PowerShell console
- **Error handling:** Try/catch blocks with user-friendly error messages

### Impact Analysis (Safety Features)
- **Pre-operation checks:** Before rename/delete, queries data table for field usage
- **Smart detection:** Identifies non-default values (TRUE flags, non-NULL dates, non-zero numbers, non-empty text)
- **Usage preview:** Shows TOP 100 affected records in DataGridView
- **User confirmation required:** Cannot proceed without explicit approval
- **Prevents accidental data loss:** Protects actively-used fields from unintended changes

---

## Known Limitations

1. **No Undo/Redo:** Changes saved immediately to database
2. **Single Record Editing:** Cannot edit multiple records simultaneously
3. **Fixed Field Count:** Hardcoded to 30 fields per table
4. **Limited Record Lists:** Product/Account limited to TOP 100
5. **No Field Reordering:** CustomOrderNum not implemented
6. **No Bulk Import:** Must enter data one record at a time
7. **No Data Export:** Cannot export custom field data to CSV

---

## Future Enhancement Opportunities

1. **Bulk Edit Mode:** Edit multiple records at once
2. **Search/Filter:** Find records by custom field values
3. **Import/Export CSV:** Bulk data operations
4. **Validation Rules:** Configure required fields, min/max values
5. **Field Dependencies:** Conditional field visibility/requirements
6. **Audit History:** Track who changed what and when
7. **Field Templates:** Pre-configured field sets for common scenarios
8. **Custom Field Wizard:** Guided setup for new field definitions

---

## Support Information

### Getting Help
- Review console output for detailed error messages
- Check SQL Server connectivity via SSMS
- Verify registry values: HKCU:\SOFTWARE\Backoffice
- Confirm database permissions (SELECT, UPDATE, INSERT, DELETE)

### Providing Feedback
- Use thumbs down button in Claude.ai interface
- Include specific error messages from console
- Note which tab/operation failed
- Describe expected vs actual behavior

---

## Version History

### Version 2.0 - Enhanced Edition (January 31, 2026)
- ✅ Fixed CustomFieldType mapping (0=Flag, 1=Date, 2=Num, 3=Text)
- ✅ Fixed CustomTableID mapping (0=Account, 1=Product, etc.)
- ✅ Added Supplier table support (TableID=3)
- ✅ Added "Manage Field Names" tab with full CRUD
- ✅ Improved GUI layout and usability
- ✅ Enhanced error handling and validation
- ✅ Updated documentation

### Version 1.0 - Initial Release (January 30, 2026)
- Basic custom field data editing
- Support for 6 tables (no Supplier)
- Incorrect field type/table ID mapping
- No field name management UI

---

## File Manifest

- `BepozCustomFieldsManager_Enhanced.ps1` - Main application (2,200+ lines)
- `RunCustomFieldsManager_Enhanced.bat` - Batch launcher
- `CustomFieldsManager_Enhanced_README.md` - This file

---

## Quick Reference Card

### CustomFieldType Values
- 0 = Flag (checkbox)
- 1 = Date (date picker)
- 2 = Number (numeric textbox)
- 3 = Text (text textbox)

### CustomTableID Values
- 0 = Account
- 1 = Product
- 2 = Operator
- 3 = Supplier
- 5 = Store
- 7 = Venue
- 8 = Workstation

### Field Counts Per Type
- Flag: 1-10 (CustomFlag_1..10)
- Date: 1-5 (CustomDate_1..5)
- Number: 1-5 (CustomNum_1..5)
- Text: 1-10 (CustomText_1..10)

### Keyboard Shortcuts
- Tab: Move between fields
- Enter: Activate focused button
- Esc: Close dialog boxes

---

**Status:** ✅ Production Ready  
**Version:** 2.1 Enhanced Edition with Safety Features  
**Date:** January 31, 2026  
**Tables Supported:** 7  
**Custom Fields Managed:** 210 (30 per table)  
**Safety Features:** ✅ Impact Analysis Before Rename/Delete
