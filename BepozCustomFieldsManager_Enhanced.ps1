#Requires -Version 5.1

<#
.SYNOPSIS
    Bepoz Custom Fields Manager - Enhanced Edition
.DESCRIPTION
    Comprehensive GUI tool for managing custom field definitions AND values across Bepoz database tables.
    Features:
    - Manage field name definitions in dbo.CustomField
    - Edit custom field values for 7 core tables
    - Support for 30 custom fields per table (10 flags, 5 dates, 5 numbers, 10 text)
.NOTES
    Author: Bepoz Administration Team
    Version: 2.0
    PowerShell Version: 5.1+
    
    CustomFieldType Mapping:
    0 = Flag (bit)
    1 = Date (datetime)
    2 = Number (int)
    3 = Text (nvarchar)
    
    CustomTableID Mapping:
    0 = Account
    1 = Product
    2 = Operator
    3 = Supplier
    5 = Store
    7 = Venue
    8 = Workstation
#>

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Database Helper Functions

function Get-BepozConnectionString {
    <#
    .SYNOPSIS
        Retrieves Bepoz database connection string from registry
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $regPath = 'HKCU:\SOFTWARE\Backoffice'
        Write-Host "Reading registry: $regPath (User: $env:USERNAME)" -ForegroundColor Yellow
        
        if (-not (Test-Path $regPath)) {
            throw "Registry path not found: $regPath"
        }
        
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        
        $sqlServer = $props.SQL_Server
        $sqlDb = $props.SQL_DSN
        
        Write-Host "  SQL_Server: $sqlServer" -ForegroundColor Cyan
        Write-Host "  SQL_DSN: $sqlDb" -ForegroundColor Cyan
        
        if ([string]::IsNullOrWhiteSpace($sqlServer)) {
            throw "Missing HKCU:\SOFTWARE\Backoffice\SQL_Server"
        }
        
        if ([string]::IsNullOrWhiteSpace($sqlDb)) {
            throw "Missing HKCU:\SOFTWARE\Backoffice\SQL_DSN"
        }
        
        $connStr = "Server=$sqlServer;Database=$sqlDb;Integrated Security=True;TrustServerCertificate=True;Application Name=BepozCustomFieldsManager;"
        
        Write-Host "Connection string built successfully`n" -ForegroundColor Green
        return $connStr
    }
    catch {
        Write-Host "ERROR in Get-BepozConnectionString: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Invoke-BepozQuery {
    <#
    .SYNOPSIS
        Executes a SQL query and returns a DataTable
    #>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [string]$Query,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [int]$CommandTimeout = 30
    )
    
    $connection = $null
    $command = $null
    $adapter = $null
    
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $command = New-Object System.Data.SqlClient.SqlCommand($Query, $connection)
        $command.CommandTimeout = $CommandTimeout
        
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                $command.Parameters.AddWithValue($key, [DBNull]::Value) | Out-Null
            }
            else {
                $command.Parameters.AddWithValue($key, $value) | Out-Null
            }
        }
        
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        $dataTable = New-Object System.Data.DataTable
        
        [void]$adapter.Fill($dataTable)
        
        Write-Output -NoEnumerate $dataTable
        return
    }
    catch {
        Write-Host "SQL Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        if ($adapter) { $adapter.Dispose() }
        if ($command) { $command.Dispose() }
        if ($connection) { $connection.Dispose() }
    }
}

function Invoke-BepozNonQuery {
    <#
    .SYNOPSIS
        Executes a non-query SQL command (INSERT/UPDATE/DELETE)
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [string]$Query,
        
        [Parameter()]
        [hashtable]$Parameters = @{},
        
        [Parameter()]
        [int]$CommandTimeout = 30
    )
    
    $connection = $null
    $command = $null
    
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $command = New-Object System.Data.SqlClient.SqlCommand($Query, $connection)
        $command.CommandTimeout = $CommandTimeout
        
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($null -eq $value) {
                $command.Parameters.AddWithValue($key, [DBNull]::Value) | Out-Null
            }
            else {
                $command.Parameters.AddWithValue($key, $value) | Out-Null
            }
        }
        
        $connection.Open()
        $rowsAffected = $command.ExecuteNonQuery()
        
        return $rowsAffected
    }
    catch {
        Write-Host "SQL Error: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
    finally {
        if ($command) { $command.Dispose() }
        if ($connection) { $connection.Dispose() }
    }
}

#endregion

#region Custom Field Definition Functions

function Get-CustomFieldDefinitions {
    <#
    .SYNOPSIS
        Loads custom field definitions from dbo.CustomField table
    .DESCRIPTION
        CustomTableID mapping:
        0 = Account, 1 = Product, 2 = Operator, 3 = Supplier
        5 = Store, 7 = Venue, 8 = Workstation
        
        CustomFieldType mapping:
        0 = Flag (bit), 1 = Date (datetime), 2 = Number (int), 3 = Text (nvarchar)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString
    )
    
    try {
        $query = @"
SELECT 
    CustomTableID,
    CustomFieldType,
    CustomFieldNum,
    CustomOrderNum,
    Name,
    DateUpdated
FROM dbo.CustomField
ORDER BY CustomTableID, CustomFieldType, CustomFieldNum
"@
        
        return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
    }
    catch {
        Write-Host "WARNING: Could not load CustomField definitions: $($_.Exception.Message)" -ForegroundColor Yellow
        return New-Object System.Data.DataTable
    }
}

function Get-CustomFieldName {
    <#
    .SYNOPSIS
        Gets friendly name for a custom field, or returns default name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$CustomFieldDefinitions,
        
        [Parameter(Mandatory)]
        [int]$TableID,
        
        [Parameter(Mandatory)]
        [int]$FieldType,
        
        [Parameter(Mandatory)]
        [int]$FieldNum
    )
    
    foreach ($row in $CustomFieldDefinitions.Rows) {
        if ($row['CustomTableID'] -eq $TableID -and 
            $row['CustomFieldType'] -eq $FieldType -and 
            $row['CustomFieldNum'] -eq $FieldNum) {
            return $row['Name']
        }
    }
    
    # Return default name if not found
    $typeNames = @{
        0 = 'Flag'
        1 = 'Date'
        2 = 'Num'
        3 = 'Text'
    }
    
    $typeName = $typeNames[$FieldType]
    return "Custom${typeName}_${FieldNum}"
}

function Get-CustomFieldsForTable {
    <#
    .SYNOPSIS
        Returns list of custom fields for a specific table with friendly names
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [int]$TableID,
        
        [Parameter(Mandatory)]
        [System.Data.DataTable]$CustomFieldDefinitions
    )
    
    $fields = @()
    
    # Field type counts: 0=Flag(10), 1=Date(5), 2=Num(5), 3=Text(10)
    $fieldCounts = @{
        0 = 10  # CustomFlag_1..10
        1 = 5   # CustomDate_1..5
        2 = 5   # CustomNum_1..5
        3 = 10  # CustomText_1..10
    }
    
    foreach ($fieldType in @(0, 1, 2, 3)) {
        $maxFields = $fieldCounts[$fieldType]
        
        for ($i = 1; $i -le $maxFields; $i++) {
            $friendlyName = Get-CustomFieldName `
                -CustomFieldDefinitions $CustomFieldDefinitions `
                -TableID $TableID `
                -FieldType $fieldType `
                -FieldNum $i
            
            $columnName = switch ($fieldType) {
                0 { "CustomFlag_$i" }
                1 { "CustomDate_$i" }
                2 { "CustomNum_$i" }
                3 { "CustomText_$i" }
            }
            
            $dataType = switch ($fieldType) {
                0 { 'bit' }
                1 { 'datetime' }
                2 { 'int' }
                3 { 'nvarchar' }
            }
            
            $fields += [PSCustomObject]@{
                FieldType = $fieldType
                FieldNum = $i
                ColumnName = $columnName
                FriendlyName = $friendlyName
                DataType = $dataType
            }
        }
    }
    
    return $fields
}

function Get-RecordCustomFields {
    <#
    .SYNOPSIS
        Retrieves custom field values for a specific record
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [string]$TableName,
        
        [Parameter(Mandatory)]
        [string]$IDColumnName,
        
        [Parameter(Mandatory)]
        [int]$RecordID
    )
    
    $query = @"
SELECT 
    CustomFlag_1, CustomFlag_2, CustomFlag_3, CustomFlag_4, CustomFlag_5,
    CustomFlag_6, CustomFlag_7, CustomFlag_8, CustomFlag_9, CustomFlag_10,
    CustomDate_1, CustomDate_2, CustomDate_3, CustomDate_4, CustomDate_5,
    CustomNum_1, CustomNum_2, CustomNum_3, CustomNum_4, CustomNum_5,
    CustomText_1, CustomText_2, CustomText_3, CustomText_4, CustomText_5,
    CustomText_6, CustomText_7, CustomText_8, CustomText_9, CustomText_10
FROM dbo.$TableName
WHERE $IDColumnName = @RecordID
"@
    
    $params = @{ '@RecordID' = $RecordID }
    $result = Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
    
    if ($result.Rows.Count -gt 0) {
        return $result.Rows[0]
    }
    
    return $null
}

function Update-RecordCustomFields {
    <#
    .SYNOPSIS
        Updates custom field values for a specific record
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [string]$TableName,
        
        [Parameter(Mandatory)]
        [string]$IDColumnName,
        
        [Parameter(Mandatory)]
        [int]$RecordID,
        
        [Parameter(Mandatory)]
        [hashtable]$FieldValues
    )
    
    if ($FieldValues.Count -eq 0) {
        Write-Host "No fields to update" -ForegroundColor Yellow
        return 0
    }
    
    # Build SET clause
    $setClauses = @()
    $params = @{ '@RecordID' = $RecordID }
    
    foreach ($key in $FieldValues.Keys) {
        $setClauses += "$key = @$key"
        $params["@$key"] = $FieldValues[$key]
    }
    
    $setClause = $setClauses -join ', '
    $query = "UPDATE dbo.$TableName SET $setClause WHERE $IDColumnName = @RecordID"
    
    Write-Host "Updating $TableName ID $RecordID with $($FieldValues.Count) field(s)" -ForegroundColor Yellow
    
    $rowsAffected = Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
    
    Write-Host "  Updated $rowsAffected row(s)" -ForegroundColor Green
    
    return $rowsAffected
}

#endregion

#region Custom Field Name Management Functions

function Get-TableNameFromID {
    <#
    .SYNOPSIS
        Maps CustomTableID to friendly table name
    #>
    [CmdletBinding()]
    param([int]$TableID)
    
    $tableMap = @{
        0 = 'Account'
        1 = 'Product'
        2 = 'Operator'
        3 = 'Supplier'
        5 = 'Store'
        7 = 'Venue'
        8 = 'Workstation'
    }
    
    return $tableMap[$TableID]
}

function Get-TableIDFromName {
    <#
    .SYNOPSIS
        Maps table name to CustomTableID
    #>
    [CmdletBinding()]
    param([string]$TableName)
    
    $idMap = @{
        'Account' = 0
        'Product' = 1
        'Operator' = 2
        'Supplier' = 3
        'Store' = 5
        'Venue' = 7
        'Workstation' = 8
    }
    
    return $idMap[$TableName]
}

function Get-FieldTypeIDFromName {
    <#
    .SYNOPSIS
        Maps field type name to CustomFieldType ID
    #>
    [CmdletBinding()]
    param([string]$TypeName)
    
    $typeMap = @{
        'Flag' = 0
        'Date' = 1
        'Number' = 2
        'Text' = 3
    }
    
    return $typeMap[$TypeName]
}

function Get-FieldTypeNameFromID {
    <#
    .SYNOPSIS
        Maps CustomFieldType to friendly name
    #>
    [CmdletBinding()]
    param([int]$FieldType)
    
    $typeMap = @{
        0 = 'Flag'
        1 = 'Date'
        2 = 'Number'
        3 = 'Text'
    }
    
    return $typeMap[$FieldType]
}

function Add-CustomFieldDefinition {
    <#
    .SYNOPSIS
        Adds a new CustomField definition
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [int]$TableID,
        
        [Parameter(Mandatory)]
        [int]$FieldType,
        
        [Parameter(Mandatory)]
        [int]$FieldNum,
        
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        # Check if already exists
        $checkQuery = @"
SELECT COUNT(*) AS RecordCount 
FROM dbo.CustomField 
WHERE CustomTableID = @TableID 
  AND CustomFieldType = @FieldType 
  AND CustomFieldNum = @FieldNum
"@
        
        $checkParams = @{
            '@TableID' = $TableID
            '@FieldType' = $FieldType
            '@FieldNum' = $FieldNum
        }
        
        $result = Invoke-BepozQuery -ConnectionString $ConnectionString -Query $checkQuery -Parameters $checkParams
        
        if ($result.Rows[0]['RecordCount'] -gt 0) {
            Write-Host "  CustomField definition already exists - use Update instead" -ForegroundColor Yellow
            return $false
        }
        
        # Insert new definition
        $insertQuery = @"
INSERT INTO dbo.CustomField (
    CustomTableID,
    CustomFieldType,
    CustomFieldNum,
    CustomOrderNum,
    DateUpdated,
    Name
)
VALUES (
    @TableID,
    @FieldType,
    @FieldNum,
    -1,
    GETDATE(),
    @Name
)
"@
        
        $insertParams = @{
            '@TableID' = $TableID
            '@FieldType' = $FieldType
            '@FieldNum' = $FieldNum
            '@Name' = $Name
        }
        
        $rowsAffected = Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $insertQuery -Parameters $insertParams
        
        Write-Host "  Added CustomField definition: $Name" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "  ERROR adding CustomField: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Update-CustomFieldDefinition {
    <#
    .SYNOPSIS
        Updates an existing CustomField definition name
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [int]$TableID,
        
        [Parameter(Mandatory)]
        [int]$FieldType,
        
        [Parameter(Mandatory)]
        [int]$FieldNum,
        
        [Parameter(Mandatory)]
        [string]$NewName
    )
    
    try {
        $query = @"
UPDATE dbo.CustomField 
SET 
    Name = @NewName,
    DateUpdated = GETDATE()
WHERE CustomTableID = @TableID
  AND CustomFieldType = @FieldType
  AND CustomFieldNum = @FieldNum
"@
        
        $params = @{
            '@TableID' = $TableID
            '@FieldType' = $FieldType
            '@FieldNum' = $FieldNum
            '@NewName' = $NewName
        }
        
        $rowsAffected = Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
        
        if ($rowsAffected -gt 0) {
            Write-Host "  Updated CustomField definition: $NewName" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  WARNING: CustomField definition not found" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  ERROR updating CustomField: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Remove-CustomFieldDefinition {
    <#
    .SYNOPSIS
        Deletes a CustomField definition
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory)]
        [int]$TableID,
        
        [Parameter(Mandatory)]
        [int]$FieldType,
        
        [Parameter(Mandatory)]
        [int]$FieldNum
    )
    
    try {
        $query = @"
DELETE FROM dbo.CustomField
WHERE CustomTableID = @TableID
  AND CustomFieldType = @FieldType
  AND CustomFieldNum = @FieldNum
"@
        
        $params = @{
            '@TableID' = $TableID
            '@FieldType' = $FieldType
            '@FieldNum' = $FieldNum
        }
        
        $rowsAffected = Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
        
        if ($rowsAffected -gt 0) {
            Write-Host "  Deleted CustomField definition" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "  WARNING: CustomField definition not found" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  ERROR deleting CustomField: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Table-Specific Functions

function Get-VenueList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT VenueID, Name FROM dbo.Venue ORDER BY Name"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-StoreList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT StoreID, Name FROM dbo.Store ORDER BY Name"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-WorkstationList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT WorkstationID, Name FROM dbo.Workstation ORDER BY Name"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-ProductList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT TOP 100 ProductID, Name FROM dbo.Product WHERE ProdType <> 1 ORDER BY Name"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-AccountList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = @"
SELECT TOP 100 
    AccountID, 
    COALESCE(FirstName + ' ' + LastName, AccNumber) AS DisplayName
FROM dbo.Account 
ORDER BY LastName, FirstName
"@
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-OperatorList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = @"
SELECT 
    OperatorID, 
    COALESCE(FirstName + ' ' + LastName, 'Operator ' + CAST(OperatorID AS varchar)) AS DisplayName
FROM dbo.Operator 
ORDER BY LastName, FirstName
"@
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-SupplierList {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = @"
SELECT 
    SupplierID,
    Name
FROM dbo.Supplier
ORDER BY Name
"@
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

#endregion

#region GUI Functions

function New-CustomFieldEditor {
    <#
    .SYNOPSIS
        Creates editor controls for a custom field
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Panel]$Container,
        
        [Parameter(Mandatory)]
        [PSCustomObject]$Field,
        
        [Parameter()]
        [object]$Value,
        
        [Parameter(Mandatory)]
        [int]$YPosition
    )
    
    # Label
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, $YPosition)
    $label.Size = New-Object System.Drawing.Size(200, 20)
    $label.Text = $Field.FriendlyName
    $Container.Controls.Add($label)
    
    # Editor control based on type
    $control = $null
    
    switch ($Field.DataType) {
        'bit' {
            # Checkbox for boolean
            $control = New-Object System.Windows.Forms.CheckBox
            $control.Location = New-Object System.Drawing.Point(220, $YPosition)
            $control.Size = New-Object System.Drawing.Size(20, 20)
            
            if ($null -ne $Value -and -not [DBNull]::Value.Equals($Value)) {
                $control.Checked = [bool]$Value
            }
        }
        
        'datetime' {
            # DateTimePicker for datetime
            $control = New-Object System.Windows.Forms.DateTimePicker
            $control.Location = New-Object System.Drawing.Point(220, $YPosition)
            $control.Size = New-Object System.Drawing.Size(200, 25)
            $control.Format = 'Custom'
            $control.CustomFormat = 'yyyy-MM-dd HH:mm'
            
            if ($null -ne $Value -and -not [DBNull]::Value.Equals($Value)) {
                $control.Value = [datetime]$Value
            }
        }
        
        'int' {
            # TextBox for integer
            $control = New-Object System.Windows.Forms.TextBox
            $control.Location = New-Object System.Drawing.Point(220, $YPosition)
            $control.Size = New-Object System.Drawing.Size(150, 25)
            
            if ($null -ne $Value -and -not [DBNull]::Value.Equals($Value)) {
                $control.Text = $Value.ToString()
            }
        }
        
        'nvarchar' {
            # TextBox for text
            $control = New-Object System.Windows.Forms.TextBox
            $control.Location = New-Object System.Drawing.Point(220, $YPosition)
            $control.Size = New-Object System.Drawing.Size(400, 25)
            $control.MaxLength = 8000
            
            if ($null -ne $Value -and -not [DBNull]::Value.Equals($Value)) {
                $control.Text = $Value.ToString()
            }
        }
    }
    
    # Store field metadata in Tag
    $control.Tag = $Field
    
    $Container.Controls.Add($control)
    
    return $control
}

function Show-CustomFieldsManager {
    <#
    .SYNOPSIS
        Main GUI for Custom Fields Manager
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionString
    )
    
    # Load custom field definitions
    $customFieldDefs = Get-CustomFieldDefinitions -ConnectionString $ConnectionString
    
    Write-Host "Loaded $($customFieldDefs.Rows.Count) custom field definition(s)" -ForegroundColor Cyan
    
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Bepoz Custom Fields Manager - Enhanced Edition'
    $form.Size = New-Object System.Drawing.Size(900, 750)
    $form.StartPosition = 'CenterScreen'
    $form.MaximizeBox = $false
    $form.FormBorderStyle = 'FixedDialog'
    
    # Header
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Location = New-Object System.Drawing.Point(20, 20)
    $lblHeader.Size = New-Object System.Drawing.Size(600, 30)
    $lblHeader.Text = 'Custom Fields Manager'
    $lblHeader.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblHeader)
    
    # Instructions
    $lblInstructions = New-Object System.Windows.Forms.Label
    $lblInstructions.Location = New-Object System.Drawing.Point(20, 55)
    $lblInstructions.Size = New-Object System.Drawing.Size(850, 20)
    $lblInstructions.Text = 'Manage custom field definitions and edit field values across 7 Bepoz tables'
    $lblInstructions.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($lblInstructions)
    
    # Tab Control
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(20, 80)
    $tabControl.Size = New-Object System.Drawing.Size(850, 600)
    $form.Controls.Add($tabControl)
    
    # Status Bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = 'Ready'
    $statusBar.Items.Add($statusLabel) | Out-Null
    $form.Controls.Add($statusBar)
    
    # Close button
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Location = New-Object System.Drawing.Point(780, 685)
    $btnClose.Size = New-Object System.Drawing.Size(90, 30)
    $btnClose.Text = 'Close'
    $btnClose.Add_Click({ $form.Close() })
    $form.Controls.Add($btnClose)
    
    #region Field Name Manager Tab
    
    $tabFieldNames = New-Object System.Windows.Forms.TabPage
    $tabFieldNames.Text = '⚙ Manage Field Names'
    $tabFieldNames.Padding = New-Object System.Windows.Forms.Padding(10)
    $tabControl.TabPages.Add($tabFieldNames)
    
    # Instructions
    $lblFNInstructions = New-Object System.Windows.Forms.Label
    $lblFNInstructions.Location = New-Object System.Drawing.Point(10, 10)
    $lblFNInstructions.Size = New-Object System.Drawing.Size(800, 40)
    $lblFNInstructions.Text = "Define friendly names for custom fields. These names appear in all data tabs instead of technical names.`nSelect table and field type to view/manage definitions, or add new definitions below."
    $lblFNInstructions.ForeColor = [System.Drawing.Color]::DarkBlue
    $tabFieldNames.Controls.Add($lblFNInstructions)
    
    # Table selection
    $lblFNTable = New-Object System.Windows.Forms.Label
    $lblFNTable.Location = New-Object System.Drawing.Point(10, 60)
    $lblFNTable.Size = New-Object System.Drawing.Size(80, 20)
    $lblFNTable.Text = 'Table:'
    $tabFieldNames.Controls.Add($lblFNTable)
    
    $cmbFNTable = New-Object System.Windows.Forms.ComboBox
    $cmbFNTable.Location = New-Object System.Drawing.Point(100, 60)
    $cmbFNTable.Size = New-Object System.Drawing.Size(150, 25)
    $cmbFNTable.DropDownStyle = 'DropDownList'
    @('Account', 'Operator', 'Product', 'Supplier', 'Store', 'Venue', 'Workstation') | ForEach-Object {
        $cmbFNTable.Items.Add($_) | Out-Null
    }
    $tabFieldNames.Controls.Add($cmbFNTable)
    
    # Load Fields button
    $btnFNLoad = New-Object System.Windows.Forms.Button
    $btnFNLoad.Location = New-Object System.Drawing.Point(260, 60)
    $btnFNLoad.Size = New-Object System.Drawing.Size(100, 25)
    $btnFNLoad.Text = 'Load Fields'
    $btnFNLoad.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
    $btnFNLoad.ForeColor = [System.Drawing.Color]::White
    $btnFNLoad.FlatStyle = 'Flat'
    $tabFieldNames.Controls.Add($btnFNLoad)
    
    # DataGridView for field list
    $dgvFieldNames = New-Object System.Windows.Forms.DataGridView
    $dgvFieldNames.Location = New-Object System.Drawing.Point(10, 95)
    $dgvFieldNames.Size = New-Object System.Drawing.Size(810, 365)
    $dgvFieldNames.AllowUserToAddRows = $false
    $dgvFieldNames.AllowUserToDeleteRows = $false
    $dgvFieldNames.SelectionMode = 'FullRowSelect'
    $dgvFieldNames.MultiSelect = $false
    $dgvFieldNames.ReadOnly = $true
    $dgvFieldNames.AutoSizeColumnsMode = 'Fill'
    $tabFieldNames.Controls.Add($dgvFieldNames)
    
    # Separator
    $lblFNSeparator = New-Object System.Windows.Forms.Label
    $lblFNSeparator.Location = New-Object System.Drawing.Point(10, 470)
    $lblFNSeparator.Size = New-Object System.Drawing.Size(810, 2)
    $lblFNSeparator.BorderStyle = 'Fixed3D'
    $tabFieldNames.Controls.Add($lblFNSeparator)
    
    # Add/Edit Section Header
    $lblFNEditHeader = New-Object System.Windows.Forms.Label
    $lblFNEditHeader.Location = New-Object System.Drawing.Point(10, 480)
    $lblFNEditHeader.Size = New-Object System.Drawing.Size(400, 20)
    $lblFNEditHeader.Text = 'Add New Field Definition or Edit Selected:'
    $lblFNEditHeader.Font = New-Object System.Drawing.Font($lblFNEditHeader.Font, [System.Drawing.FontStyle]::Bold)
    $tabFieldNames.Controls.Add($lblFNEditHeader)
    
    # Field Type selection for add/edit
    $lblFNTypeEdit = New-Object System.Windows.Forms.Label
    $lblFNTypeEdit.Location = New-Object System.Drawing.Point(10, 510)
    $lblFNTypeEdit.Size = New-Object System.Drawing.Size(80, 20)
    $lblFNTypeEdit.Text = 'Field Type:'
    $tabFieldNames.Controls.Add($lblFNTypeEdit)
    
    $cmbFNTypeEdit = New-Object System.Windows.Forms.ComboBox
    $cmbFNTypeEdit.Location = New-Object System.Drawing.Point(100, 510)
    $cmbFNTypeEdit.Size = New-Object System.Drawing.Size(100, 25)
    $cmbFNTypeEdit.DropDownStyle = 'DropDownList'
    @('Flag', 'Date', 'Number', 'Text') | ForEach-Object {
        $cmbFNTypeEdit.Items.Add($_) | Out-Null
    }
    $tabFieldNames.Controls.Add($cmbFNTypeEdit)
    
    # Field Number selection for add/edit
    $lblFNNumEdit = New-Object System.Windows.Forms.Label
    $lblFNNumEdit.Location = New-Object System.Drawing.Point(210, 510)
    $lblFNNumEdit.Size = New-Object System.Drawing.Size(60, 20)
    $lblFNNumEdit.Text = 'Field #:'
    $tabFieldNames.Controls.Add($lblFNNumEdit)
    
    $cmbFNNumEdit = New-Object System.Windows.Forms.ComboBox
    $cmbFNNumEdit.Location = New-Object System.Drawing.Point(280, 510)
    $cmbFNNumEdit.Size = New-Object System.Drawing.Size(60, 25)
    $cmbFNNumEdit.DropDownStyle = 'DropDownList'
    $tabFieldNames.Controls.Add($cmbFNNumEdit)
    
    # Field name editor
    $lblFNName = New-Object System.Windows.Forms.Label
    $lblFNName.Location = New-Object System.Drawing.Point(350, 510)
    $lblFNName.Size = New-Object System.Drawing.Size(80, 20)
    $lblFNName.Text = 'Field Name:'
    $tabFieldNames.Controls.Add($lblFNName)
    
    $txtFNName = New-Object System.Windows.Forms.TextBox
    $txtFNName.Location = New-Object System.Drawing.Point(440, 510)
    $txtFNName.Size = New-Object System.Drawing.Size(250, 25)
    $txtFNName.MaxLength = 50
    $tabFieldNames.Controls.Add($txtFNName)
    
    # Action buttons
    $btnFNAdd = New-Object System.Windows.Forms.Button
    $btnFNAdd.Location = New-Object System.Drawing.Point(700, 510)
    $btnFNAdd.Size = New-Object System.Drawing.Size(60, 25)
    $btnFNAdd.Text = 'Add'
    $btnFNAdd.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnFNAdd.ForeColor = [System.Drawing.Color]::White
    $btnFNAdd.FlatStyle = 'Flat'
    $tabFieldNames.Controls.Add($btnFNAdd)
    
    $btnFNUpdate = New-Object System.Windows.Forms.Button
    $btnFNUpdate.Location = New-Object System.Drawing.Point(770, 510)
    $btnFNUpdate.Size = New-Object System.Drawing.Size(50, 25)
    $btnFNUpdate.Text = 'Save'
    $btnFNUpdate.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnFNUpdate.ForeColor = [System.Drawing.Color]::White
    $btnFNUpdate.FlatStyle = 'Flat'
    $tabFieldNames.Controls.Add($btnFNUpdate)
    
    # Delete button
    $btnFNDelete = New-Object System.Windows.Forms.Button
    $btnFNDelete.Location = New-Object System.Drawing.Point(700, 543)
    $btnFNDelete.Size = New-Object System.Drawing.Size(120, 25)
    $btnFNDelete.Text = 'Delete Selected'
    $btnFNDelete.BackColor = [System.Drawing.Color]::FromArgb(192, 0, 0)
    $btnFNDelete.ForeColor = [System.Drawing.Color]::White
    $btnFNDelete.FlatStyle = 'Flat'
    $tabFieldNames.Controls.Add($btnFNDelete)
    
    # Field Type changed - update field number dropdown for add/edit
    $cmbFNTypeEdit.Add_SelectedIndexChanged({
        $cmbFNNumEdit.Items.Clear()
        
        $maxNum = switch ($cmbFNTypeEdit.SelectedItem) {
            'Flag' { 10 }
            'Date' { 5 }
            'Number' { 5 }
            'Text' { 10 }
            default { 0 }
        }
        
        for ($i = 1; $i -le $maxNum; $i++) {
            $cmbFNNumEdit.Items.Add($i) | Out-Null
        }
        
        if ($cmbFNNumEdit.Items.Count -gt 0) {
            $cmbFNNumEdit.SelectedIndex = 0
        }
    })
    
    # Load Fields button
    $btnFNLoad.Add_Click({
        try {
            if (-not $cmbFNTable.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select a table', 'Validation', 'OK', 'Warning')
                return
            }
            
            $statusLabel.Text = 'Loading field definitions...'
            $form.Refresh()
            
            $selectedTableID = Get-TableIDFromName -TableName $cmbFNTable.SelectedItem
            
            # Query all field definitions for this table
            $query = @"
SELECT 
    CustomTableID,
    CustomFieldType,
    CustomFieldNum,
    Name,
    DateUpdated
FROM dbo.CustomField
WHERE CustomTableID = @TableID
ORDER BY CustomFieldType, CustomFieldNum
"@
            
            $result = Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@TableID' = $selectedTableID }
            
            # Setup DataGridView columns
            $dgvFieldNames.Columns.Clear()
            $dgvFieldNames.Rows.Clear()
            
            $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colType.Name = 'FieldType'
            $colType.HeaderText = 'Field Type'
            $dgvFieldNames.Columns.Add($colType)
            
            $colNum = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colNum.Name = 'FieldNum'
            $colNum.HeaderText = 'Field #'
            $dgvFieldNames.Columns.Add($colNum)
            
            $colTechName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colTechName.Name = 'TechnicalName'
            $colTechName.HeaderText = 'Technical Name'
            $dgvFieldNames.Columns.Add($colTechName)
            
            $colFriendly = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colFriendly.Name = 'FriendlyName'
            $colFriendly.HeaderText = 'Friendly Name'
            $dgvFieldNames.Columns.Add($colFriendly)
            
            $colUpdated = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colUpdated.Name = 'Updated'
            $colUpdated.HeaderText = 'Last Updated'
            $dgvFieldNames.Columns.Add($colUpdated)
            
            # Hidden columns
            $colTableID = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colTableID.Name = 'TableID'
            $colTableID.Visible = $false
            $dgvFieldNames.Columns.Add($colTableID)
            
            $colTypeID = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
            $colTypeID.Name = 'TypeID'
            $colTypeID.Visible = $false
            $dgvFieldNames.Columns.Add($colTypeID)
            
            # Populate grid
            foreach ($row in $result.Rows) {
                $fieldTypeID = [int]$row['CustomFieldType']
                $fieldNum = [int]$row['CustomFieldNum']
                
                $fieldTypeName = Get-FieldTypeNameFromID -FieldType $fieldTypeID
                
                $techName = switch ($fieldTypeID) {
                    0 { "CustomFlag_$fieldNum" }
                    1 { "CustomDate_$fieldNum" }
                    2 { "CustomNum_$fieldNum" }
                    3 { "CustomText_$fieldNum" }
                }
                
                $dgvFieldNames.Rows.Add(
                    $fieldTypeName,
                    $fieldNum,
                    $techName,
                    $row['Name'],
                    $row['DateUpdated'],
                    $selectedTableID,
                    $fieldTypeID
                )
            }
            
            $statusLabel.Text = "Loaded $($result.Rows.Count) field definition(s) for $($cmbFNTable.SelectedItem)"
        }
        catch {
            $statusLabel.Text = 'Error loading field definitions'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Grid row selected - populate edit fields
    $dgvFieldNames.Add_SelectionChanged({
        if ($dgvFieldNames.SelectedRows.Count -gt 0) {
            $selectedRow = $dgvFieldNames.SelectedRows[0]
            
            # Set field type
            $fieldTypeName = $selectedRow.Cells['FieldType'].Value
            for ($i = 0; $i -lt $cmbFNTypeEdit.Items.Count; $i++) {
                if ($cmbFNTypeEdit.Items[$i] -eq $fieldTypeName) {
                    $cmbFNTypeEdit.SelectedIndex = $i
                    break
                }
            }
            
            # Set field number
            $fieldNum = $selectedRow.Cells['FieldNum'].Value
            for ($i = 0; $i -lt $cmbFNNumEdit.Items.Count; $i++) {
                if ($cmbFNNumEdit.Items[$i] -eq $fieldNum) {
                    $cmbFNNumEdit.SelectedIndex = $i
                    break
                }
            }
            
            # Set name
            $txtFNName.Text = $selectedRow.Cells['FriendlyName'].Value
        }
    })
    
    # Add button
    $btnFNAdd.Add_Click({
        try {
            if (-not $cmbFNTable.SelectedItem -or -not $cmbFNTypeEdit.SelectedItem -or $null -eq $cmbFNNumEdit.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select Table, Field Type, and Field Number', 'Validation', 'OK', 'Warning')
                return
            }
            
            if ([string]::IsNullOrWhiteSpace($txtFNName.Text)) {
                [System.Windows.Forms.MessageBox]::Show('Please enter a field name', 'Validation', 'OK', 'Warning')
                return
            }
            
            $tableID = Get-TableIDFromName -TableName $cmbFNTable.SelectedItem
            $typeID = Get-FieldTypeIDFromName -TypeName $cmbFNTypeEdit.SelectedItem
            $fieldNum = [int]$cmbFNNumEdit.SelectedItem
            $fieldName = $txtFNName.Text.Trim()
            
            $statusLabel.Text = 'Adding field definition...'
            $form.Refresh()
            
            $success = Add-CustomFieldDefinition `
                -ConnectionString $ConnectionString `
                -TableID $tableID `
                -FieldType $typeID `
                -FieldNum $fieldNum `
                -Name $fieldName
            
            if ($success) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Successfully added field definition!`n`nTable: $($cmbFNTable.SelectedItem)`nType: $($cmbFNTypeEdit.SelectedItem)`nNumber: $fieldNum`nName: $fieldName",
                    'Success',
                    'OK',
                    'Information'
                )
                
                # Reload definitions
                $script:customFieldDefs = Get-CustomFieldDefinitions -ConnectionString $ConnectionString
                
                # Refresh grid
                $btnFNLoad.PerformClick()
                
                $statusLabel.Text = 'Field definition added successfully'
            }
            else {
                $statusLabel.Text = 'Field definition already exists - use Save to update'
            }
        }
        catch {
            $statusLabel.Text = 'Error adding field definition'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to add: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Update button
    $btnFNUpdate.Add_Click({
        try {
            if ($dgvFieldNames.SelectedRows.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select a field definition from the grid', 'Validation', 'OK', 'Warning')
                return
            }
            
            if ([string]::IsNullOrWhiteSpace($txtFNName.Text)) {
                [System.Windows.Forms.MessageBox]::Show('Please enter a field name', 'Validation', 'OK', 'Warning')
                return
            }
            
            $selectedRow = $dgvFieldNames.SelectedRows[0]
            $tableID = [int]$selectedRow.Cells['TableID'].Value
            $typeID = [int]$selectedRow.Cells['TypeID'].Value
            $fieldNum = [int]$selectedRow.Cells['FieldNum'].Value
            $newName = $txtFNName.Text.Trim()
            
            $statusLabel.Text = 'Updating field definition...'
            $form.Refresh()
            
            $success = Update-CustomFieldDefinition `
                -ConnectionString $ConnectionString `
                -TableID $tableID `
                -FieldType $typeID `
                -FieldNum $fieldNum `
                -NewName $newName
            
            if ($success) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Successfully updated field definition!`n`nNew name: $newName",
                    'Success',
                    'OK',
                    'Information'
                )
                
                # Reload definitions
                $script:customFieldDefs = Get-CustomFieldDefinitions -ConnectionString $ConnectionString
                
                # Refresh grid
                $btnFNLoad.PerformClick()
                
                $statusLabel.Text = 'Field definition updated successfully'
            }
            else {
                $statusLabel.Text = 'Failed to update - definition not found'
            }
        }
        catch {
            $statusLabel.Text = 'Error updating field definition'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to update: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Delete button
    $btnFNDelete.Add_Click({
        try {
            if ($dgvFieldNames.SelectedRows.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select a field definition from the grid', 'Validation', 'OK', 'Warning')
                return
            }
            
            $selectedRow = $dgvFieldNames.SelectedRows[0]
            $tableID = [int]$selectedRow.Cells['TableID'].Value
            $typeID = [int]$selectedRow.Cells['TypeID'].Value
            $fieldNum = [int]$selectedRow.Cells['FieldNum'].Value
            $fieldName = $selectedRow.Cells['FriendlyName'].Value
            
            $confirmMsg = "Are you sure you want to delete this field definition?`n`n" +
                         "Table: $($cmbFNTable.SelectedItem)`n" +
                         "Field: $($selectedRow.Cells['TechnicalName'].Value)`n" +
                         "Name: $fieldName`n`n" +
                         "Note: This only deletes the friendly name, not the actual data."
            
            $result = [System.Windows.Forms.MessageBox]::Show(
                $confirmMsg,
                'Confirm Delete',
                'YesNo',
                'Warning'
            )
            
            if ($result -ne 'Yes') {
                return
            }
            
            $statusLabel.Text = 'Deleting field definition...'
            $form.Refresh()
            
            $success = Remove-CustomFieldDefinition `
                -ConnectionString $ConnectionString `
                -TableID $tableID `
                -FieldType $typeID `
                -FieldNum $fieldNum
            
            if ($success) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Successfully deleted field definition!",
                    'Success',
                    'OK',
                    'Information'
                )
                
                # Reload definitions
                $script:customFieldDefs = Get-CustomFieldDefinitions -ConnectionString $ConnectionString
                
                # Refresh grid
                $btnFNLoad.PerformClick()
                
                $statusLabel.Text = 'Field definition deleted successfully'
            }
            else {
                $statusLabel.Text = 'Failed to delete - definition not found'
            }
        }
        catch {
            $statusLabel.Text = 'Error deleting field definition'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to delete: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    #endregion
    
    # Create data editor tabs for each table
    $tables = @(
        @{ Name = 'Venue'; TableID = 7; TableName = 'Venue'; IDColumn = 'VenueID'; DisplayColumn = 'Name'; LoadFunc = { Get-VenueList -ConnectionString $ConnectionString } }
        @{ Name = 'Store'; TableID = 5; TableName = 'Store'; IDColumn = 'StoreID'; DisplayColumn = 'Name'; LoadFunc = { Get-StoreList -ConnectionString $ConnectionString } }
        @{ Name = 'Workstation'; TableID = 8; TableName = 'Workstation'; IDColumn = 'WorkstationID'; DisplayColumn = 'Name'; LoadFunc = { Get-WorkstationList -ConnectionString $ConnectionString } }
        @{ Name = 'Product'; TableID = 1; TableName = 'Product'; IDColumn = 'ProductID'; DisplayColumn = 'Name'; LoadFunc = { Get-ProductList -ConnectionString $ConnectionString } }
        @{ Name = 'Account'; TableID = 0; TableName = 'Account'; IDColumn = 'AccountID'; DisplayColumn = 'DisplayName'; LoadFunc = { Get-AccountList -ConnectionString $ConnectionString } }
        @{ Name = 'Operator'; TableID = 2; TableName = 'Operator'; IDColumn = 'OperatorID'; DisplayColumn = 'DisplayName'; LoadFunc = { Get-OperatorList -ConnectionString $ConnectionString } }
        @{ Name = 'Supplier'; TableID = 3; TableName = 'Supplier'; IDColumn = 'SupplierID'; DisplayColumn = 'Name'; LoadFunc = { Get-SupplierList -ConnectionString $ConnectionString } }
    )
    
    foreach ($tableConfig in $tables) {
        # Create tab
        $tab = New-Object System.Windows.Forms.TabPage
        $tab.Text = $tableConfig.Name
        $tab.Padding = New-Object System.Windows.Forms.Padding(10)
        $tabControl.TabPages.Add($tab)
        
        # Record selector
        $lblRecord = New-Object System.Windows.Forms.Label
        $lblRecord.Location = New-Object System.Drawing.Point(10, 10)
        $lblRecord.Size = New-Object System.Drawing.Size(100, 20)
        $lblRecord.Text = "Select $($tableConfig.Name):"
        $tab.Controls.Add($lblRecord)
        
        $cmbRecord = New-Object System.Windows.Forms.ComboBox
        $cmbRecord.Location = New-Object System.Drawing.Point(120, 10)
        $cmbRecord.Size = New-Object System.Drawing.Size(400, 25)
        $cmbRecord.DropDownStyle = 'DropDownList'
        $tab.Controls.Add($cmbRecord)
        
        # Load Fields button
        $btnLoad = New-Object System.Windows.Forms.Button
        $btnLoad.Location = New-Object System.Drawing.Point(530, 10)
        $btnLoad.Size = New-Object System.Drawing.Size(100, 25)
        $btnLoad.Text = 'Load Fields'
        $btnLoad.Enabled = $false
        $tab.Controls.Add($btnLoad)
        
        # Save Changes button
        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Location = New-Object System.Drawing.Point(640, 10)
        $btnSave.Size = New-Object System.Drawing.Size(100, 25)
        $btnSave.Text = 'Save Changes'
        $btnSave.Enabled = $false
        $btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnSave.ForeColor = [System.Drawing.Color]::White
        $btnSave.FlatStyle = 'Flat'
        $tab.Controls.Add($btnSave)
        
        # Scrollable panel for fields
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Location = New-Object System.Drawing.Point(10, 45)
        $panel.Size = New-Object System.Drawing.Size(810, 510)
        $panel.AutoScroll = $true
        $panel.BorderStyle = 'FixedSingle'
        $tab.Controls.Add($panel)
        
        # Load records into dropdown
        try {
            $records = & $tableConfig.LoadFunc
            
            foreach ($record in $records.Rows) {
                $id = $record[$tableConfig.IDColumn]
                $displayValue = $record[$tableConfig.DisplayColumn]
                
                $item = [PSCustomObject]@{
                    Text = "$id - $displayValue"
                    ID = $id
                }
                
                $cmbRecord.Items.Add($item) | Out-Null
            }
            
            $cmbRecord.DisplayMember = 'Text'
            
            if ($cmbRecord.Items.Count -gt 0) {
                $cmbRecord.SelectedIndex = 0
            }
        }
        catch {
            Write-Host "ERROR loading $($tableConfig.Name) records: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Record selected - enable Load button
        $cmbRecord.Add_SelectedIndexChanged({
            $btnLoad.Enabled = ($cmbRecord.SelectedItem -ne $null)
        }.GetNewClosure())
        
        # Load Fields button
        $btnLoad.Add_Click({
            try {
                $statusLabel.Text = "Loading custom fields for $($tableConfig.Name)..."
                $form.Refresh()
                
                $panel.Controls.Clear()
                
                $selectedID = $cmbRecord.SelectedItem.ID
                
                # Get custom fields for this table
                $fields = Get-CustomFieldsForTable `
                    -ConnectionString $ConnectionString `
                    -TableID $tableConfig.TableID `
                    -CustomFieldDefinitions $script:customFieldDefs
                
                # Get current values
                $currentValues = Get-RecordCustomFields `
                    -ConnectionString $ConnectionString `
                    -TableName $tableConfig.TableName `
                    -IDColumnName $tableConfig.IDColumn `
                    -RecordID $selectedID
                
                # Create editors
                $yPos = 10
                
                foreach ($field in $fields) {
                    $value = if ($currentValues) { $currentValues[$field.ColumnName] } else { $null }
                    
                    $control = New-CustomFieldEditor `
                        -Container $panel `
                        -Field $field `
                        -Value $value `
                        -YPosition $yPos
                    
                    $yPos += 35
                }
                
                $btnSave.Enabled = $true
                $statusLabel.Text = "Loaded $($fields.Count) custom fields"
            }
            catch {
                $statusLabel.Text = 'Error loading custom fields'
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to load fields: $($_.Exception.Message)",
                    'Error',
                    'OK',
                    'Error'
                )
            }
        }.GetNewClosure())
        
        # Save Changes button
        $btnSave.Add_Click({
            try {
                $selectedID = $cmbRecord.SelectedItem.ID
                
                # Collect values from controls
                $fieldValues = @{}
                
                foreach ($control in $panel.Controls) {
                    if ($control.Tag -and $control.Tag -is [PSCustomObject]) {
                        $field = $control.Tag
                        $columnName = $field.ColumnName
                        
                        $value = switch ($field.DataType) {
                            'bit' { if ($control.Checked) { 1 } else { 0 } }
                            'datetime' { $control.Value }
                            'int' {
                                if ([string]::IsNullOrWhiteSpace($control.Text)) {
                                    [DBNull]::Value
                                }
                                else {
                                    try {
                                        [int]$control.Text
                                    }
                                    catch {
                                        [DBNull]::Value
                                    }
                                }
                            }
                            'nvarchar' {
                                if ([string]::IsNullOrWhiteSpace($control.Text)) {
                                    [DBNull]::Value
                                }
                                else {
                                    $control.Text
                                }
                            }
                        }
                        
                        $fieldValues[$columnName] = $value
                    }
                }
                
                # Confirm save
                $confirmMsg = "Save custom field changes for:`n`n" +
                             "$($tableConfig.Name): $($cmbRecord.SelectedItem.Text)`n`n" +
                             "$($fieldValues.Count) field(s) will be updated.`n`n" +
                             "Continue?"
                
                $result = [System.Windows.Forms.MessageBox]::Show(
                    $confirmMsg,
                    'Confirm Save',
                    'YesNo',
                    'Question'
                )
                
                if ($result -ne 'Yes') {
                    return
                }
                
                $statusLabel.Text = 'Saving custom fields...'
                $form.Refresh()
                
                # Update database
                $rowsAffected = Update-RecordCustomFields `
                    -ConnectionString $ConnectionString `
                    -TableName $tableConfig.TableName `
                    -IDColumnName $tableConfig.IDColumn `
                    -RecordID $selectedID `
                    -FieldValues $fieldValues
                
                if ($rowsAffected -gt 0) {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Successfully saved custom fields!",
                        'Success',
                        'OK',
                        'Information'
                    )
                    
                    $statusLabel.Text = 'Custom fields saved successfully'
                }
                else {
                    $statusLabel.Text = 'No changes were made'
                }
            }
            catch {
                $statusLabel.Text = 'Error saving custom fields'
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to save: $($_.Exception.Message)",
                    'Error',
                    'OK',
                    'Error'
                )
            }
        }.GetNewClosure())
    }
    
    # Show form
    [void]$form.ShowDialog()
}

#endregion

#region Main Entry Point

try {
    Write-Host "`n=== Bepoz Custom Fields Manager - Enhanced Edition ===" -ForegroundColor Cyan
    Write-Host "User: $env:USERNAME" -ForegroundColor Yellow
    
    $connStr = Get-BepozConnectionString
    
    Show-CustomFieldsManager -ConnectionString $connStr
}
catch {
    Write-Host "`nFATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "Fatal error:`n`n$($_.Exception.Message)",
        'Fatal Error',
        'OK',
        'Error'
    )
}
finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

#endregion
