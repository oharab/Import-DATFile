# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

PowerShell-based data import utility that reads pipe-separated .dat files and imports them into SQL Server databases. Uses Excel specification file (`ExportSpec.xlsx`) to define table schemas and field mappings.

## Core Architecture

### Modular Design (Refactored v2.0 - Private/Public Structure)

**Module Structure:**
The project now follows PowerShell best practices with a clear Private/Public folder separation:

```
Import-DATFile/
├── SqlServerDataImport.psm1          # Root module loader (dot-sources all functions)
├── SqlServerDataImport.psd1          # Module manifest
├── Import-DATFile.Common.psm1        # Shared utilities (used by CLI/GUI)
│
├── Public/                            # Public API (exported functions)
│   └── Invoke-SqlServerDataImport.ps1    # Main entry point
│
├── Private/                           # Internal implementation (not exported)
│   ├── Configuration/                    # Module configuration
│   │   ├── Import-DATFile.Constants.ps1     # Centralized constants
│   │   └── TypeMappings.psd1                # Data type mappings
│   │
│   ├── Database/                         # Database operations (6 functions)
│   │   ├── Test-DatabaseConnection.ps1
│   │   ├── New-DatabaseSchema.ps1
│   │   ├── Test-TableExists.ps1
│   │   ├── New-DatabaseTable.ps1
│   │   ├── Remove-DatabaseTable.ps1
│   │   └── Clear-DatabaseTable.ps1
│   │
│   ├── DataImport/                       # Import pipeline (4 functions)
│   │   ├── Read-DatFileLines.ps1
│   │   ├── Add-DataTableRows.ps1
│   │   ├── Invoke-SqlBulkCopy.ps1
│   │   └── Import-DataFile.ps1
│   │
│   ├── Specification/                    # Excel/file processing (2 functions)
│   │   ├── Get-DataPrefix.ps1
│   │   └── Get-TableSpecifications.ps1
│   │
│   ├── PostInstall/                      # Post-import scripts (1 function)
│   │   └── Invoke-PostInstallScripts.ps1
│   │
│   └── Logging/                          # Logging & summary (4 functions)
│       ├── Write-ImportLog.ps1
│       ├── Add-ImportSummary.ps1
│       ├── Show-ImportSummary.ps1
│       └── Clear-ImportSummary.ps1
│
├── Import-CLI.ps1                     # Command-line interface
└── Import-GUI.ps1                     # Windows Forms GUI
```

**Benefits of Private/Public Structure:**
- **Clear API Surface**: Only `Invoke-SqlServerDataImport` is exported
- **Better Organization**: Functions grouped by concern (Database, DataImport, etc.)
- **Easier Testing**: Can test private functions independently
- **Improved Maintainability**: Smaller, focused files (~100 lines each)
- **Team Collaboration**: Reduced merge conflicts, easier code reviews
- **Encapsulation**: Internal implementation details hidden from consumers

**Core Modules:**
- **SqlServerDataImport.psm1**: Root module loader
  - Dot-sources all Private and Public functions
  - Loads Configuration (Constants and TypeMappings from Private/Configuration)
  - Loads Common utilities module (Import-DATFile.Common.psm1)
  - Exports only Public functions via manifest
  - Initializes global variables ($script:ImportSummary)
  - No business logic - pure loader pattern

- **Import-DATFile.Common.psm1**: Shared utilities module
  - Common functions used across CLI, GUI, and core module
  - Lives in root directory (imported by CLI/GUI)
  - Connection string building (`New-SqlConnectionString`)
  - Module initialization (`Initialize-ImportModules`)
  - Type mapping functions (switch-based)
  - Type conversion utilities (`ConvertTo-TypedValue`)
  - Validation functions (`Test-ImportPath`, `Test-SchemaName`)
  - Eliminates code duplication between CLI and GUI

**User Interfaces:**
- **Import-CLI.ps1**: Interactive command-line interface
  - Prompts user for configuration (data folder, Excel file, connection details)
  - Uses common module for connection string building
  - Supports both interactive and parameter-based execution
  - Console-based progress display

- **Import-GUI.ps1**: Windows Forms graphical interface
  - Rich UI with file browsers, connection builders, and real-time output
  - Uses System.Windows.Forms for native Windows GUI
  - Uses common module for connection string building
  - Background runspace execution to prevent UI freezing
  - Captures and displays console output in real-time

- **Launch-Import-GUI.bat**: One-click launcher for GUI
  - Simple batch file to launch Import-GUI.ps1
  - Sets PowerShell execution policy for the session

**Dependencies:**
- SqlServer module (external)
- ImportExcel module (external)
- All internal modules interconnected for code reuse

### Key Components
1. **Prefix Detection**: Automatically detects file prefix by finding `*Employee.dat` file
2. **Schema Management**: Creates database schemas based on detected prefix
3. **Dynamic Table Creation**: Builds SQL tables from Excel specifications
4. **High-Performance Data Import**: Uses SqlBulkCopy exclusively for optimal performance (no fallbacks)
5. **Interactive Configuration**: Prompts for data folder, Excel file, database connection and schema details

### Data Flow
1. Script detects prefix from Employee.dat file presence
2. Reads table/field specifications from Excel file
3. Establishes SQL Server connection (Windows or SQL auth)
4. Creates schema and tables based on specifications
5. Imports data from matching .dat files using high-performance SqlBulkCopy
6. Displays comprehensive import summary with row counts

### Core Module Functions (SqlServerDataImport.psm1)

**File and Specification Functions:**
- `Get-DataPrefix`: Detects data file prefix by locating *Employee.dat file
- `Get-TableSpecifications`: Reads and parses Excel specification file
- `Get-SqlDataTypeMapping`: Maps Excel data types to SQL Server types
- `Get-DotNetDataType`: Maps SQL types to .NET types for DataTable columns

**Database Management Functions:**
- `Test-DatabaseConnection`: Validates SQL Server connectivity
- `Test-TableExists`: Checks if a table exists in the database
- `New-DatabaseSchema`: Creates database schema if it doesn't exist
- `New-DatabaseTable`: Creates table with ImportID + specification fields
- `Remove-DatabaseTable`: Drops existing table (for Recreate action)
- `Clear-DatabaseTable`: Truncates table data (for Truncate action)

**Import Functions:**
- `Import-DataFile`: Core function that reads .dat file and bulk imports using SqlBulkCopy
  - Creates DataTable structure with ImportID first and proper .NET types for each column
  - Validates strict field count matching
  - Populates DataTable rows from pipe-separated data with type conversion:
    - DateTime parsing for date/time columns
    - Numeric conversion for INT, BIGINT, DECIMAL, MONEY columns
    - Direct assignment for string columns
    - Graceful error handling with warnings for conversion failures
  - Performs SqlBulkCopy operation with column mappings
  - Returns row count imported

**Post-Install Script Functions:**
- `Invoke-PostInstallScripts`: Executes SQL template files after import completes
  - Parameters: ScriptPath, ConnectionString, DatabaseName, SchemaName
  - Supports single file or folder of .sql files
  - Replaces {{DATABASE}} and {{SCHEMA}} placeholders
  - Executes scripts in alphabetical order
  - Returns detailed success/failure summary
  - 300-second timeout per script

**Summary and Reporting:**
- `Add-ImportSummary`: Tracks imported tables and row counts
- `Show-ImportSummary`: Displays formatted import summary
- `Clear-ImportSummary`: Resets summary for new import session

**Main Entry Point:**
- `Invoke-SqlServerDataImport`: Orchestrates the entire import process
  - Parameters: DataFolder, ExcelSpecFile, ConnectionString, SchemaName, TableExistsAction, PostInstallScripts, Verbose
  - Handles table conflict resolution (Ask, Skip, Truncate, Recreate)
  - Processes all matching .dat files
  - Optionally executes post-install scripts after import
  - Supports verbose logging for detailed operational information
  - Returns comprehensive results

**Logging System:**
- `Write-ImportLog`: Centralized logging with multiple severity levels
  - Levels: INFO, SUCCESS, WARNING, ERROR, VERBOSE, DEBUG
  - VERBOSE and DEBUG messages only display when verbose mode is enabled
  - Color-coded console output for easy reading
  - Timestamped messages for tracking execution flow

## Critical Design Constraints

**IMPORTANT: This is an OPTIMIZED version with strict requirements:**

1. **ImportID Field Requirement**: Every .dat file MUST have ImportID as the first field
   - Expected field count = 1 (ImportID) + Excel spec field count
   - Fail-fast on mismatches (no dynamic field skipping)

2. **SqlBulkCopy ONLY**: No INSERT fallbacks
   - Import fails immediately if SqlBulkCopy encounters issues
   - This is intentional for performance (67% faster)

3. **No File Logging**: Console output only
   - Eliminates slow disk I/O during import

4. **Multi-Line Field Support**: Records can span multiple lines
   - Parser accumulates lines until expected field count reached
   - Embedded newlines (CR/LF) preserved in data

## Configuration Architecture

### Type Mappings (Switch Statement Pattern)
Type mappings use switch statements within conversion functions for better type safety:
- **Get-SqlDataTypeMapping.ps1**: Excel types → SQL Server types (switch on Excel type names)
- **Get-DotNetDataType.ps1**: SQL types → .NET types for DataTable columns
- **ConvertTo-TypedValue.ps1**: Dictionary dispatch pattern for routing to specialized converters
- Add new types by adding cases to switch statements (provides IntelliSense and compile-time safety)

### Constants (Locality of Behavior)
Constants are defined within their domain functions to maintain locality of behavior:
- **Invoke-SqlBulkCopy.ps1**: Bulk copy configuration (`$batchSize = 10000`, `$timeoutSeconds = 300`)
- **Add-DataTableRows.ps1**: Progress reporting interval (`$progressInterval = 10000`)
- **Test-IsNullValue.ps1**: NULL representations (`@('NULL', 'NA', 'N/A')`)
- **ConvertTo-BooleanValue.ps1**: Boolean value mappings (TRUE/FALSE, YES/NO, 1/0, etc.)
- **ConvertTo-DateTimeValue.ps1**: Supported date formats (ISO 8601 variants)

**Rationale:** These constants rarely change and are tightly coupled to their functions. Keeping them local improves readability, reduces indirection, and makes it clear where configuration values are used. This follows the principle of locality of behavior over premature abstraction.

## Data Format Requirements (Critical for Type Conversion)

These formats are enforced in `Import-DATFile.Common.psm1` → `ConvertTo-TypedValue`:

- **Dates**: `yyyy-MM-dd HH:mm:ss.fff` (tries multiple formats, InvariantCulture)
- **Decimals**: Period separator, InvariantCulture (e.g., `123.45` NOT `123,45`)
- **Integers**: Accepts decimal notation (e.g., `123.0` → 123)
- **Boolean**: `1/0`, `TRUE/FALSE`, `YES/NO`, `Y/N`, `T/F` (case insensitive)
- **NULL**: Empty, whitespace, `NULL`, `NA`, `N/A` (case insensitive)

**Why InvariantCulture?** Prevents locale-dependent parsing issues (e.g., European comma decimals)

## Performance Optimization

**Key Optimizations:**
- SqlBulkCopy ONLY (no INSERT fallbacks)
- No file logging (console only)
- Strict validation with fail-fast
- Proper .NET type mapping in DataTable
- Minimal memory footprint

**Performance:** ~67% faster than original (1M rows: 2 min → 40 sec)

## Security

- Schema validation: `^[a-zA-Z0-9_]+$` (prevents SQL injection)
- Table/column names properly bracketed
- SqlBulkCopy API prevents data-based injection

## Architecture Patterns

### Separation of Concerns
The modular design ensures clean separation between:
1. **Data Processing Logic** (SqlServerDataImport.psm1): Pure functions with no UI dependencies
2. **User Interfaces** (Import-CLI.ps1, Import-GUI.ps1): Handle user interaction, delegate to module
3. **Configuration** (Excel specification file): External schema definitions

### Module Reusability
The core module can be imported into any PowerShell script:
```powershell
Import-Module .\SqlServerDataImport.psm1

$params = @{
    DataFolder = "C:\Data"
    ExcelSpecFile = "ExportSpec.xlsx"
    ConnectionString = "Server=localhost;Database=MyDB;Integrated Security=True;"
    SchemaName = "MySchema"
    TableExistsAction = "Truncate"
}

Invoke-SqlServerDataImport @params
```

### Error Handling Strategy
- **Validation-first**: All inputs validated before processing begins
- **Fail-fast**: Errors halt execution immediately with clear messages
- **Detailed logging**: Timestamped logs with severity levels (INFO, SUCCESS, WARNING, ERROR)
- **No silent failures**: All errors are surfaced to the user

## Common Development Pitfalls

**Adding new features that break fail-fast behavior**:
- Don't add fallback INSERT logic (intentionally removed for performance)
- Don't add interactive field-skipping prompts (optimized version is strict)

**Type conversion issues**:
- Always use InvariantCulture for numeric/date parsing
- Update constants within their domain functions (see "Constants (Locality of Behavior)" section)
- Add new type mappings to switch statements in `Get-SqlDataTypeMapping` and `Get-DotNetDataType`

**Breaking DRY principle**:
- Check `Import-DATFile.Common.psm1` before duplicating code
- CLI and GUI should delegate to common module functions

**Violating SRP**:
- Keep functions focused (~100 lines max)
- See `Private/DataImport/` for example of proper function decomposition

## Refactoring (2025-10-10)

Refactored to follow DRY and SOLID principles with 100% backward compatibility.
Branch: `refactor/dry-solid-improvements`

### Key Improvements

**1. DRY Principle**: Centralized common code in `Import-DATFile.Common.psm1` (eliminated 70+ duplicate lines)

**2. Single Responsibility (SRP)**: Split `Import-DataFile` (280 lines, 8+ responsibilities) into focused functions:
- `Read-DatFileLines`, `New-ImportDataTable`, `Add-DataTableRows`, `Invoke-SqlBulkCopy`, `Import-DataFile`

**3. Open/Closed (OCP)**: Dictionary dispatch pattern in `ConvertTo-TypedValue` makes adding new types straightforward

**4. Locality of Behavior**: Constants defined within domain functions for clarity:
- Batch sizes in `Invoke-SqlBulkCopy`, progress intervals in `Add-DataTableRows`, NULL representations in `Test-IsNullValue`

**5. Enhanced Validation**: PowerShell validation attributes (`ValidateScript`, `ValidatePattern`, `ValidateSet`)

**6. Logging Strategy**: Uses built-in PowerShell cmdlets (`Write-Verbose`, `Write-Debug`, `Write-Warning`, `Write-Error`)

### Benefits
- 30% less code duplication
- Better testability and maintainability
- Easy extension (add switch cases or dictionary entries)
- Self-documenting parameters
- Local constants improve code readability

### Common Module Functions
See `Import-DATFile.Common.psm1` for shared utilities:
- Module initialization, connection strings, validation
- Type mapping and conversion (switch-based with dictionary dispatch)
- DataTable creation

### Maintenance

**Add new data types**: Add switch cases to `Get-SqlDataTypeMapping` and `Get-DotNetDataType` functions

**Modify configuration**: Update constants within domain functions:
  - Bulk copy settings: Edit `Invoke-SqlBulkCopy.ps1`
  - Progress intervals: Edit `Add-DataTableRows.ps1`
  - NULL representations: Edit `Test-IsNullValue.ps1`

**Add validations**: Add functions to `Import-DATFile.Common.psm1` and export

**Function help**: All functions have comment-based help (`Get-Help <Function-Name> -Full`)

### Development Guidelines

When adding features:
1. Check Common module first (DRY)
2. Define constants locally within functions (locality of behavior)
3. Add type mappings to switch statements (provides IntelliSense)
4. Follow SRP (focused functions)
5. Add parameter validation attributes
6. Include comment-based help
7. New functions should be created in the Private/ or Public/ folder structures, as part of their area of responsibility
8. Each cmdlet should be created in its own file