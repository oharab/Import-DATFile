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
│
├── Public/                            # Public API (exported functions)
│   └── Invoke-SqlServerDataImport.ps1    # Main entry point
│
├── Private/                           # Internal implementation (not exported)
│   ├── Database/                         # Database operations (9 functions)
│   │   ├── Clear-DatabaseTable.ps1
│   │   ├── Get-DatabaseErrorGuidance.ps1
│   │   ├── Get-DatabaseNameFromConnectionString.ps1
│   │   ├── New-DatabaseSchema.ps1
│   │   ├── New-DatabaseTable.ps1
│   │   ├── New-SqlConnectionString.ps1
│   │   ├── Remove-DatabaseTable.ps1
│   │   ├── Test-DatabaseConnection.ps1
│   │   └── Test-TableExists.ps1
│   │
│   ├── DataImport/                       # Import pipeline (14 functions)
│   │   ├── Add-DataTableRows.ps1
│   │   ├── ConvertTo-BooleanValue.ps1
│   │   ├── ConvertTo-DateTimeValue.ps1
│   │   ├── ConvertTo-DecimalValue.ps1
│   │   ├── ConvertTo-IntegerValue.ps1
│   │   ├── ConvertTo-TypedValue.ps1
│   │   ├── Get-ConversionGuidance.ps1
│   │   ├── Get-DotNetDataType.ps1
│   │   ├── Get-SqlDataTypeMapping.ps1
│   │   ├── Import-DataFile.ps1
│   │   ├── Invoke-SqlBulkCopy.ps1
│   │   ├── New-ImportDataTable.ps1
│   │   ├── Read-DatFileLines.ps1
│   │   └── Test-IsNullValue.ps1
│   │
│   ├── Initialization/                   # Module initialization (1 function)
│   │   └── Initialize-ImportModules.ps1
│   │
│   ├── Logging/                          # Logging & summary (4 functions)
│   │   ├── Add-ImportSummary.ps1
│   │   ├── Clear-ImportSummary.ps1
│   │   ├── Show-ImportSummary.ps1
│   │   └── Write-ImportLog.ps1
│   │
│   ├── Orchestration/                    # Workflow orchestration (5 functions)
│   │   ├── Complete-ImportProcess.ps1
│   │   ├── Initialize-ImportContext.ps1
│   │   ├── Invoke-TableImportProcess.ps1
│   │   ├── Show-ValidationSummary.ps1
│   │   └── Test-DataFileValidation.ps1
│   │
│   ├── PostInstall/                      # Post-import scripts (1 function)
│   │   └── Invoke-PostInstallScripts.ps1
│   │
│   ├── Specification/                    # Excel/file processing (3 functions)
│   │   ├── Get-DataPrefix.ps1
│   │   ├── Get-TableSpecifications.ps1
│   │   └── Test-ExcelSpecification.ps1
│   │
│   └── Validation/                       # Input validation (2 functions)
│       ├── Test-ImportPath.ps1
│       └── Test-SchemaName.ps1
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

**Core Module:**
- **SqlServerDataImport.psm1**: Root module loader
  - Dot-sources all Private and Public functions recursively
  - Calls `Initialize-ImportModules` to load external dependencies (SqlServer, ImportExcel)
  - Exports only Public functions via manifest
  - Initializes global variables ($script:ImportSummary, $script:VerboseLogging)
  - No business logic - pure loader pattern

**User Interfaces:**
- **Import-CLI.ps1**: Interactive command-line interface
  - Prompts user for configuration (data folder, Excel file, connection details)
  - Imports SqlServerDataImport.psm1 module
  - Supports both interactive and parameter-based execution
  - Console-based progress display

- **Import-GUI.ps1**: Windows Forms graphical interface
  - Rich UI with file browsers, connection builders, and real-time output
  - Uses System.Windows.Forms for native Windows GUI
  - Imports SqlServerDataImport.psm1 module
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

### Core Module Functions by Folder

**Public/ - Exported API (1 function):**
- `Invoke-SqlServerDataImport`: Main orchestrator for the entire import process
  - Parameters: DataFolder, ExcelSpecFile, Server, Database, Username, Password, SchemaName, TableExistsAction, PostInstallScripts, ValidateOnly, Verbose
  - Handles table conflict resolution (Skip, Truncate, Recreate)
  - Processes all matching .dat files
  - Optionally executes post-install scripts after import
  - Supports validation-only mode (no database changes)
  - Returns comprehensive import summary or validation results

**Private/Database/ - Database operations (9 functions):**
- `New-SqlConnectionString`: Builds SQL Server connection strings (Windows/SQL auth)
- `Get-DatabaseNameFromConnectionString`: Extracts database name from connection string
- `Get-DatabaseErrorGuidance`: Provides user-friendly error messages for database issues
- `Test-DatabaseConnection`: Validates SQL Server connectivity
- `Test-TableExists`: Checks if a table exists in the database
- `New-DatabaseSchema`: Creates database schema if it doesn't exist
- `New-DatabaseTable`: Creates table with ImportID + specification fields
- `Remove-DatabaseTable`: Drops existing table (for Recreate action)
- `Clear-DatabaseTable`: Truncates table data (for Truncate action)

**Private/DataImport/ - Import pipeline (14 functions):**
- `Read-DatFileLines`: Reads pipe-separated DAT files with multi-line record support
- `Get-SqlDataTypeMapping`: Maps Excel data types to SQL Server types (switch-based)
- `Get-DotNetDataType`: Maps SQL types to .NET types for DataTable columns (switch-based)
- `New-ImportDataTable`: Creates DataTable structure from field specifications
- `Test-IsNullValue`: Checks if a value represents NULL (empty, "NULL", "NA", "N/A")
- `ConvertTo-TypedValue`: Central type conversion dispatcher (dictionary pattern)
- `ConvertTo-DateTimeValue`: Converts strings to DateTime (InvariantCulture, multiple formats)
- `ConvertTo-IntegerValue`: Converts strings to Int32/Int64 (InvariantCulture)
- `ConvertTo-DecimalValue`: Converts strings to Decimal/Double/Single (InvariantCulture)
- `ConvertTo-BooleanValue`: Converts strings to Boolean (1/0, TRUE/FALSE, YES/NO, Y/N, T/F)
- `Get-ConversionGuidance`: Generates user-friendly error messages for type conversion failures
- `Add-DataTableRows`: Populates DataTable with type-converted values from records
- `Invoke-SqlBulkCopy`: Performs high-performance bulk copy to SQL Server
- `Import-DataFile`: Orchestrates file read → DataTable creation → bulk copy workflow

**Private/Initialization/ - Module setup (1 function):**
- `Initialize-ImportModules`: Loads external dependencies (SqlServer, ImportExcel modules)

**Private/Logging/ - Logging & summary (4 functions):**
- `Write-ImportLog`: Centralized logging with severity levels (INFO, SUCCESS, WARNING, ERROR, VERBOSE, DEBUG)
- `Add-ImportSummary`: Tracks imported tables and row counts
- `Show-ImportSummary`: Displays formatted import summary
- `Clear-ImportSummary`: Resets summary for new import session

**Private/Orchestration/ - Workflow coordination (5 functions):**
- `Initialize-ImportContext`: Validates inputs, detects prefix, connects to DB, creates schema, reads specs
- `Invoke-TableImportProcess`: Processes single table import (field lookup, table handling, data import)
- `Complete-ImportProcess`: Finalizes import (shows summary, runs post-install scripts)
- `Test-DataFileValidation`: Validates DAT file structure without importing
- `Show-ValidationSummary`: Displays validation results in user-friendly format

**Private/PostInstall/ - Post-import scripts (1 function):**
- `Invoke-PostInstallScripts`: Executes SQL template files after import completes
  - Supports single file or folder of .sql files
  - Replaces {{DATABASE}} and {{SCHEMA}} placeholders
  - Executes scripts in alphabetical order
  - 300-second timeout per script

**Private/Specification/ - Excel/file processing (3 functions):**
- `Get-DataPrefix`: Detects data file prefix by locating *Employee.dat file
- `Get-TableSpecifications`: Reads and parses Excel specification file
- `Test-ExcelSpecification`: Validates Excel spec structure (required columns, data types, duplicates)

**Private/Validation/ - Input validation (2 functions):**
- `Test-ImportPath`: Validates file/folder paths exist
- `Test-SchemaName`: Validates schema name format (^[a-zA-Z0-9_]+$, SQL injection prevention)

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
- **Private/DataImport/Get-SqlDataTypeMapping.ps1**: Excel types → SQL Server types (switch on Excel type names)
- **Private/DataImport/Get-DotNetDataType.ps1**: SQL types → .NET types for DataTable columns
- **Private/DataImport/ConvertTo-TypedValue.ps1**: Dictionary dispatch pattern for routing to specialized converters
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

These formats are enforced in `Private/DataImport/ConvertTo-TypedValue.ps1` and related converter functions:

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
- Add new type mappings to switch statements in `Private/DataImport/Get-SqlDataTypeMapping.ps1` and `Private/DataImport/Get-DotNetDataType.ps1`

**Breaking DRY principle**:
- Check existing Private/ functions before duplicating code
- Reuse functions across Database, DataImport, Validation, etc. folders

**Violating SRP**:
- Keep functions focused (~100 lines max)
- See `Private/DataImport/` for example of proper function decomposition (14 focused functions instead of one monolith)

## Refactoring (2025-10-10)

Refactored to follow DRY and SOLID principles with 100% backward compatibility.
Branch: `refactor/dry-solid-improvements`

### Key Improvements

**1. DRY Principle**: Organized functions into focused folders (Database, DataImport, Validation, etc.) to eliminate duplication

**2. Single Responsibility (SRP)**: Split monolithic functions into focused, testable units:
- **Import pipeline**: `Read-DatFileLines`, `New-ImportDataTable`, `Add-DataTableRows`, `Invoke-SqlBulkCopy`, `Import-DataFile`
- **Type conversion**: 14 functions in DataImport/ (one per concern: reading, mapping, converting, validating)
- **Orchestration**: 5 functions in Orchestration/ (context init, table processing, completion, validation)

**3. Open/Closed (OCP)**: Dictionary dispatch pattern in `ConvertTo-TypedValue` makes adding new types straightforward

**4. Locality of Behavior**: Constants defined within domain functions for clarity:
- Batch sizes in `Private/DataImport/Invoke-SqlBulkCopy.ps1`
- Progress intervals in `Private/DataImport/Add-DataTableRows.ps1`
- NULL representations in `Private/DataImport/Test-IsNullValue.ps1`

**5. Enhanced Validation**: PowerShell validation attributes (`ValidateScript`, `ValidatePattern`, `ValidateSet`)

**6. Folder Organization**: Functions grouped by responsibility (Database, DataImport, Orchestration, Validation, etc.)

### Benefits
- 40 focused functions instead of few monolithic ones
- Better testability (each function independently testable)
- Easier code reviews (smaller files, clear responsibilities)
- Easy extension (add switch cases or new converter functions)
- Self-documenting parameters with validation attributes
- Clear separation of concerns

### Maintenance Guidelines

**Add new data types**:
1. Add case to `Private/DataImport/Get-SqlDataTypeMapping.ps1` (Excel → SQL)
2. Add case to `Private/DataImport/Get-DotNetDataType.ps1` (SQL → .NET)
3. If complex conversion needed, create `Private/DataImport/ConvertTo-{Type}Value.ps1`
4. Register converter in `ConvertTo-TypedValue.ps1` dictionary

**Modify configuration**: Update constants within domain functions:
- Bulk copy settings: Edit `Private/DataImport/Invoke-SqlBulkCopy.ps1`
- Progress intervals: Edit `Private/DataImport/Add-DataTableRows.ps1`
- NULL representations: Edit `Private/DataImport/Test-IsNullValue.ps1`

**Add validations**: Create new function in `Private/Validation/` folder (e.g., `Test-ConnectionString.ps1`)

**Add database operations**: Create new function in `Private/Database/` folder

**Function help**: All functions have comment-based help (`Get-Help <Function-Name> -Full`)

### Development Guidelines

When adding features:
1. Determine appropriate folder: Database, DataImport, Orchestration, Validation, Specification, etc.
2. Define constants locally within functions (locality of behavior)
3. Add type mappings to switch statements (provides IntelliSense)
4. Follow SRP (focused functions, ~100 lines max)
5. Add parameter validation attributes
6. Include comment-based help with examples
7. Create one function per file in appropriate Private/ subfolder
8. Export only if needed by external consumers (add to Public/)