# Import-DATFile.Common.psm1
# Common utility functions shared across Import-DATFile system
# Implements DRY principle by centralizing reused functionality

#region Module Dependencies

# Load constants
$moduleDir = Split-Path $PSCommandPath -Parent
$constantsPath = Join-Path $moduleDir "Import-DATFile.Constants.ps1"
if (Test-Path $constantsPath) {
    . $constantsPath
}

# Load type mappings
$typeMappingsPath = Join-Path $moduleDir "TypeMappings.psd1"
if (Test-Path $typeMappingsPath) {
    $script:TypeMappings = Import-PowerShellDataFile -Path $typeMappingsPath
}
else {
    throw "TypeMappings.psd1 not found at: $typeMappingsPath"
}

#endregion

#region Module Initialization Functions

function Initialize-ImportModules {
    <#
    .SYNOPSIS
    Initializes required PowerShell modules for Import-DATFile system.

    .DESCRIPTION
    Checks for and imports SqlServer and ImportExcel modules.
    Provides consistent error messaging if modules are missing.
    Eliminates duplicate module loading code from CLI and GUI interfaces.

    .PARAMETER ThrowOnError
    If specified, throws an exception when modules are missing.
    Otherwise, returns false.

    .EXAMPLE
    Initialize-ImportModules -ThrowOnError

    .EXAMPLE
    if (-not (Initialize-ImportModules)) {
        Write-Host "Please install required modules"
        exit 1
    }
    #>
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )

    $missingModules = @()

    # Check SqlServer module
    try {
        Import-Module SqlServer -ErrorAction Stop
        Write-Verbose "SqlServer module loaded successfully"
    }
    catch {
        $missingModules += "SqlServer"
    }

    # Check ImportExcel module
    try {
        Import-Module ImportExcel -ErrorAction Stop
        Write-Verbose "ImportExcel module loaded successfully"
    }
    catch {
        $missingModules += "ImportExcel"
    }

    if ($missingModules.Count -gt 0) {
        $message = "Required modules not found: $($missingModules -join ', '). Please install using: Install-Module -Name $($missingModules -join ', ')"

        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    return $true
}

#endregion

#region Connection String Functions

function New-SqlConnectionString {
    <#
    .SYNOPSIS
    Builds a SQL Server connection string with Windows or SQL authentication.

    .DESCRIPTION
    Centralizes connection string building logic to ensure consistency.
    Supports both Windows Authentication (Integrated Security) and
    SQL Server Authentication (username/password).

    .PARAMETER Server
    SQL Server instance name (e.g., "localhost", "server\instance").

    .PARAMETER Database
    Database name.

    .PARAMETER Username
    SQL Server authentication username. If not provided, Windows Authentication is used.

    .PARAMETER Password
    SQL Server authentication password. Required when Username is provided.

    .EXAMPLE
    New-SqlConnectionString -Server "localhost" -Database "MyDB"
    # Returns: Server=localhost;Database=MyDB;Integrated Security=True;

    .EXAMPLE
    New-SqlConnectionString -Server "localhost" -Database "MyDB" -Username "sa" -Password "P@ssw0rd"
    # Returns: Server=localhost;Database=MyDB;User Id=sa;Password=P@ssw0rd;
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$Password
    )

    if (-not [string]::IsNullOrWhiteSpace($Username)) {
        # SQL Server Authentication
        if ([string]::IsNullOrWhiteSpace($Password)) {
            throw "Password is required when using SQL Server Authentication"
        }

        Write-Verbose "Building connection string with SQL Server Authentication"
        return "Server=$Server;Database=$Database;User Id=$Username;Password=$Password;"
    }
    else {
        # Windows Authentication
        Write-Verbose "Building connection string with Windows Authentication"
        return "Server=$Server;Database=$Database;Integrated Security=True;"
    }
}

function Get-DatabaseNameFromConnectionString {
    <#
    .SYNOPSIS
    Extracts database name from a connection string.

    .DESCRIPTION
    Parses a SQL Server connection string to extract the database name.
    Supports both "Database=" and "Initial Catalog=" keywords.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .EXAMPLE
    Get-DatabaseNameFromConnectionString -ConnectionString "Server=localhost;Database=MyDB;Integrated Security=True;"
    # Returns: MyDB
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString
    )

    if ($ConnectionString -match "Database=([^;]+)") {
        return $Matches[1]
    }
    elseif ($ConnectionString -match "Initial Catalog=([^;]+)") {
        return $Matches[1]
    }
    else {
        Write-Warning "Could not extract database name from connection string"
        return $null
    }
}

#endregion

#region Validation Functions

function Test-ImportPath {
    <#
    .SYNOPSIS
    Validates a file or folder path for import operations.

    .DESCRIPTION
    Provides consistent path validation with clear error messages.
    Supports validating both files and folders.

    .PARAMETER Path
    Path to validate.

    .PARAMETER PathType
    Type of path to validate: 'File' or 'Folder'.

    .PARAMETER ThrowOnError
    If specified, throws an exception on validation failure.
    Otherwise, returns false.

    .EXAMPLE
    Test-ImportPath -Path "C:\Data" -PathType Folder -ThrowOnError

    .EXAMPLE
    if (-not (Test-ImportPath -Path "C:\Data\file.xlsx" -PathType File)) {
        Write-Host "File not found"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [ValidateSet('File', 'Folder')]
        [string]$PathType,

        [switch]$ThrowOnError
    )

    $exists = $false
    $message = ""

    switch ($PathType) {
        'File' {
            $exists = Test-Path -Path $Path -PathType Leaf
            if (-not $exists) {
                $message = "File not found: $Path"
            }
        }
        'Folder' {
            $exists = Test-Path -Path $Path -PathType Container
            if (-not $exists) {
                $message = "Folder not found: $Path"
            }
        }
    }

    if (-not $exists) {
        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    Write-Verbose "$PathType validated: $Path"
    return $true
}

function Test-SchemaName {
    <#
    .SYNOPSIS
    Validates a SQL Server schema name.

    .DESCRIPTION
    Ensures schema name contains only valid characters (alphanumeric and underscore)
    to prevent SQL injection and ensure compatibility.

    .PARAMETER SchemaName
    Schema name to validate.

    .PARAMETER ThrowOnError
    If specified, throws an exception on validation failure.

    .EXAMPLE
    Test-SchemaName -SchemaName "dbo" -ThrowOnError
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [switch]$ThrowOnError
    )

    if ($SchemaName -notmatch $script:SCHEMA_NAME_PATTERN) {
        $message = "Invalid schema name: $SchemaName. Schema names must contain only letters, numbers, and underscores."

        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    Write-Verbose "Schema name validated: $SchemaName"
    return $true
}

#endregion

#region Type Mapping Functions

function Get-SqlDataTypeMapping {
    <#
    .SYNOPSIS
    Maps Excel/specification data type to SQL Server data type.

    .DESCRIPTION
    Uses configuration-based type mapping instead of hard-coded switch statements.
    Follows Open/Closed Principle - extend via configuration, not code modification.

    .PARAMETER ExcelType
    Data type from Excel specification.

    .PARAMETER Precision
    Optional precision/length for the data type.

    .EXAMPLE
    Get-SqlDataTypeMapping -ExcelType "VARCHAR" -Precision "100"
    # Returns: VARCHAR(100)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelType,

        [string]$Precision
    )

    $type = $ExcelType.ToUpper()

    # Search through type mappings in order
    foreach ($mapping in $script:TypeMappings.SqlTypeMappings) {
        if ($type -match $mapping.Pattern) {
            $sqlType = $mapping.SqlType

            # Add precision if supported and provided
            if ($mapping.UsesPrecision) {
                if ($Precision -and $Precision -ne "") {
                    $sqlType = "$sqlType($Precision)"
                }
                elseif ($mapping.DefaultPrecision) {
                    $sqlType = "$sqlType($($mapping.DefaultPrecision))"
                }
            }

            Write-Verbose "Mapped '$ExcelType' to '$sqlType'"
            return $sqlType
        }
    }

    # No match found, use default
    Write-Warning "Unknown data type: $ExcelType. Defaulting to $($script:TypeMappings.DefaultSqlType)"
    return $script:TypeMappings.DefaultSqlType
}

function Get-DotNetDataType {
    <#
    .SYNOPSIS
    Maps SQL Server data type to .NET Framework type.

    .DESCRIPTION
    Uses configuration-based type mapping for DataTable column creation.
    Returns the appropriate System.Type for the given SQL type.

    .PARAMETER SqlType
    SQL Server data type.

    .EXAMPLE
    Get-DotNetDataType -SqlType "INT"
    # Returns: [System.Int32]
    #>
    [CmdletBinding()]
    [OutputType([Type])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SqlType
    )

    $type = $SqlType.ToUpper()

    # Remove precision/scale if present (e.g., "VARCHAR(100)" -> "VARCHAR")
    if ($type -match '^([A-Z]+)') {
        $baseType = $Matches[1]
    }
    else {
        $baseType = $type
    }

    # Lookup in mappings
    if ($script:TypeMappings.DotNetTypeMappings.ContainsKey($baseType)) {
        $dotNetTypeName = $script:TypeMappings.DotNetTypeMappings[$baseType]
        $dotNetType = Invoke-Expression "[$dotNetTypeName]"
        Write-Verbose "Mapped SQL type '$SqlType' to .NET type '$dotNetTypeName'"
        return $dotNetType
    }

    # Default to String
    $defaultTypeName = $script:TypeMappings.DefaultDotNetType
    $defaultType = Invoke-Expression "[$defaultTypeName]"
    Write-Verbose "SQL type '$SqlType' not found in mappings, using default: $defaultTypeName"
    return $defaultType
}

#endregion

#region Data Conversion Functions

function ConvertTo-TypedValue {
    <#
    .SYNOPSIS
    Converts a string value to a typed value based on target .NET type.

    .DESCRIPTION
    Centralized type conversion logic with support for multiple formats and
    culture-invariant parsing. Handles NULL values, booleans, dates, and numerics.

    .PARAMETER Value
    String value to convert.

    .PARAMETER TargetType
    Target .NET type.

    .PARAMETER FieldName
    Name of the field (for error reporting).

    .PARAMETER LineNumber
    Line number in source file (for error reporting).

    .EXAMPLE
    ConvertTo-TypedValue -Value "2024-01-15" -TargetType ([DateTime]) -FieldName "BirthDate"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [Type]$TargetType,

        [Parameter(Mandatory=$false)]
        [string]$FieldName = "Unknown",

        [Parameter(Mandatory=$false)]
        [int]$LineNumber = 0
    )

    # Check for NULL values (case insensitive and whitespace aware)
    if ([string]::IsNullOrWhiteSpace($Value) -or
        ($script:NULL_REPRESENTATIONS -contains $Value.ToUpper())) {
        return [DBNull]::Value
    }

    try {
        # DateTime conversion
        if ($TargetType -eq [System.DateTime]) {
            $parsed = $false
            foreach ($format in $script:SUPPORTED_DATE_FORMATS) {
                try {
                    $result = [DateTime]::ParseExact($Value, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                    $parsed = $true
                    return $result
                }
                catch { }
            }

            if (-not $parsed) {
                # Fallback to culture-aware parsing
                return [DateTime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            }
        }

        # Int32 conversion (handles decimal notation like 123.0)
        if ($TargetType -eq [System.Int32]) {
            $decimalValue = [Decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            return [Int32]$decimalValue
        }

        # Int64 conversion (handles decimal notation)
        if ($TargetType -eq [System.Int64]) {
            $decimalValue = [Decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
            return [Int64]$decimalValue
        }

        # Double conversion (FLOAT)
        if ($TargetType -eq [System.Double]) {
            return [Double]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Single conversion (REAL)
        if ($TargetType -eq [System.Single]) {
            return [Single]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Decimal conversion (DECIMAL/NUMERIC/MONEY)
        if ($TargetType -eq [System.Decimal]) {
            return [Decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Boolean conversion
        if ($TargetType -eq [System.Boolean]) {
            $upperValue = $Value.ToUpper()
            if ($script:BOOLEAN_TRUE_VALUES -contains $upperValue) {
                return $true
            }
            elseif ($script:BOOLEAN_FALSE_VALUES -contains $upperValue) {
                return $false
            }
            else {
                Write-Warning "Invalid boolean value '$Value' for field '$FieldName' at line $LineNumber. Using False."
                return $false
            }
        }

        # String (default)
        return $Value
    }
    catch {
        Write-Warning "Error converting value '$Value' for field '$FieldName' at line $LineNumber to type $($TargetType.Name). Error: $($_.Exception.Message). Using original string value."
        return $Value
    }
}

#endregion

#region Data Table Functions

function New-ImportDataTable {
    <#
    .SYNOPSIS
    Creates a DataTable structure for import operations.

    .DESCRIPTION
    Creates a System.Data.DataTable with ImportID as the first column,
    followed by columns from the field specification. Uses proper .NET
    types for each column based on SQL type mapping.

    .PARAMETER Fields
    Array of field specifications from Excel.

    .EXAMPLE
    $dataTable = New-ImportDataTable -Fields $tableFields
    #>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    Write-Verbose "Creating DataTable structure with $($Fields.Count + 1) columns (including ImportID)"

    $dataTable = New-Object System.Data.DataTable

    # Add ImportID column first
    $importIdColumn = New-Object System.Data.DataColumn
    $importIdColumn.ColumnName = "ImportID"
    $importIdColumn.DataType = [System.String]
    $dataTable.Columns.Add($importIdColumn)

    # Add columns for each field from specification with proper data types
    foreach ($field in $Fields) {
        $column = New-Object System.Data.DataColumn
        $column.ColumnName = $field.'Column name'

        # Get SQL type and map to proper .NET type
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision
        $column.DataType = Get-DotNetDataType -SqlType $sqlType

        $dataTable.Columns.Add($column)
        Write-Verbose "Added column: $($column.ColumnName) (Type: $($column.DataType.Name))"
    }

    return $dataTable
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-ImportModules',
    'New-SqlConnectionString',
    'Get-DatabaseNameFromConnectionString',
    'Test-ImportPath',
    'Test-SchemaName',
    'Get-SqlDataTypeMapping',
    'Get-DotNetDataType',
    'ConvertTo-TypedValue',
    'New-ImportDataTable'
)
