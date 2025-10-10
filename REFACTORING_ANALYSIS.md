# PowerShell Refactoring Analysis - DRY and SOLID Principles

## Executive Summary

This document outlines identified violations of DRY (Don't Repeat Yourself) and SOLID principles in the Import-DATFile PowerShell project, along with a detailed refactoring plan to address them.

## Current Architecture

### File Structure
- `SqlServerDataImport.psm1` - Core module with all business logic
- `Import-CLI.ps1` - Interactive command-line interface
- `Import-GUI.ps1` - Windows Forms graphical interface
- `Launch-Import-GUI.bat` - Batch launcher

## Identified Issues

### 1. DRY Violations

#### 1.1 Duplicate Module Import Logic
**Location:**
- `Import-CLI.ps1:16-42`
- `Import-GUI.ps1:7-33`

**Issue:** Both files contain identical code for:
- Locating and importing SqlServerDataImport.psm1
- Checking for SqlServer module
- Checking for ImportExcel module

**Impact:** Any change to module loading requires updates in two places

#### 1.2 Duplicate Connection String Building
**Location:**
- `Import-CLI.ps1:109-130` (Get-DatabaseConnection function)
- `Import-GUI.ps1:438-448` (Start button click handler)

**Issue:** Same logic for building connection strings with Windows/SQL authentication

**Impact:** Inconsistencies in connection string format, duplicate testing

#### 1.3 Duplicate Validation Logic
**Location:** Throughout all files

**Issue:** Path validation, parameter validation repeated in multiple functions

**Impact:** Inconsistent error messages, multiple points of failure

#### 1.4 Hard-coded Color Values
**Location:** Throughout SqlServerDataImport.psm1

**Issue:** Write-Host with color codes instead of consistent Write-ImportLog usage

**Impact:** Inconsistent user experience, hard to maintain color scheme

#### 1.5 Configuration Extraction Logic
**Location:** `SqlServerDataImport.psm1:1022-1028`

**Issue:** Database name extraction from connection string should be a reusable function

**Impact:** Will need to duplicate if needed elsewhere

### 2. SOLID Violations

#### 2.1 Single Responsibility Principle (SRP)

**Violation 1: Import-DataFile Function**
**Location:** `SqlServerDataImport.psm1:419-699` (280 lines)

**Responsibilities:**
1. File reading
2. Line parsing and multi-line accumulation
3. DataTable creation
4. Type conversion for 8+ different data types
5. SqlBulkCopy configuration
6. Bulk copy execution
7. Error handling
8. Progress reporting

**Recommended Split:**
- `Read-DatFileLines` - File reading with multi-line support
- `New-ImportDataTable` - DataTable structure creation
- `ConvertTo-TypedValue` - Type conversion dispatcher
- `Invoke-SqlBulkCopy` - Bulk copy operation
- Keep `Import-DataFile` as orchestrator

**Violation 2: Invoke-SqlServerDataImport**
**Location:** `SqlServerDataImport.psm1:901-1053` (152 lines)

**Responsibilities:**
1. Path validation
2. Prefix detection
3. Database connection testing
4. Schema creation
5. File processing orchestration
6. Post-install script execution
7. Summary display
8. Error handling

**Recommended Split:**
- Extract validation into `Test-ImportPreconditions`
- Extract post-install into separate function (already done)
- Keep as thin orchestrator

**Violation 3: Write-ImportLog**
**Location:** `SqlServerDataImport.psm1:10-51`

**Issue:** Mixing log formatting with console output. Should separate concerns.

**Recommendation:**
- Use PowerShell's built-in Write-Verbose, Write-Debug, Write-Warning, Write-Error
- Keep Write-ImportLog for user-facing INFO/SUCCESS messages only

#### 2.2 Open/Closed Principle (OCP)

**Violation 1: Type Mapping Functions**
**Location:**
- `Get-SqlDataTypeMapping:57-103`
- `Get-DotNetDataType:105-124`

**Issue:** Switch statements for type mapping. Adding new types requires modifying functions.

**Recommendation:**
- Create `TypeMappings.psd1` configuration file
- Load mappings into hashtables
- Functions become data lookups, not logic containers

**Violation 2: Value Conversion Logic**
**Location:** `Import-DataFile:530-604`

**Issue:** Hard-coded conversion logic for each type. Not extensible.

**Recommendation:**
- Create type-specific converter functions
- Use hashtable dispatch pattern
- Allow custom converters to be registered

#### 2.3 Dependency Inversion Principle (DIP)

**Violation: Direct Database Dependencies**
**Location:** Throughout database functions

**Issue:** Functions directly use SqlClient and Invoke-Sqlcmd. Hard to test, hard to swap implementations.

**Note:** While ideal to create abstractions, PowerShell's dynamic nature and project scope may not justify full DIP implementation. Document this as a limitation.

### 3. PowerShell Best Practices Violations

#### 3.1 Magic Numbers
**Locations:**
- Batch size: 10000 (line 647)
- Timeout: 300 seconds (lines 648, 869)
- Progress reporting interval: 10000 (line 610)
- Preview length: 200 characters (lines 510, 865)

**Recommendation:** Create constants module

#### 3.2 Missing Parameter Validation
**Issue:** Limited use of ValidateScript, ValidateSet, ValidateNotNullOrEmpty

**Recommendation:** Add comprehensive parameter validation attributes

#### 3.3 Incomplete Comment-Based Help
**Issue:** Only some functions have complete help documentation

**Recommendation:** Add full help to all exported functions

#### 3.4 Inconsistent Output Handling
**Issue:** Mix of Write-Host, Write-ImportLog, Write-Verbose

**Recommendation:**
- Write-Verbose for debug info
- Write-Warning for warnings
- Write-Error for errors
- Write-Information for user messages (PS 5.0+)
- Write-Host only for formatted output that must bypass streams

## Refactoring Plan

### Phase 1: Foundation (No Breaking Changes)

#### 1.1 Create Constants Module
**File:** `Import-DATFile.Constants.ps1`

```powershell
# Bulk copy settings
$script:BULK_COPY_BATCH_SIZE = 10000
$script:BULK_COPY_TIMEOUT_SECONDS = 300
$script:SQL_COMMAND_TIMEOUT_SECONDS = 300

# Progress reporting
$script:PROGRESS_REPORT_INTERVAL = 10000

# Display settings
$script:PREVIEW_TEXT_LENGTH = 200

# Supported date formats
$script:DATE_FORMATS = @(
    "yyyy-MM-dd HH:mm:ss.fff",
    "yyyy-MM-dd HH:mm:ss.ff",
    "yyyy-MM-dd HH:mm:ss.f",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd"
)
```

#### 1.2 Create Type Mapping Configuration
**File:** `TypeMappings.psd1`

```powershell
@{
    SqlTypeMappings = @{
        'MONEY' = @{ Pattern = '^MONEY$'; SqlType = 'MONEY' }
        'VARCHAR' = @{ Pattern = '^VARCHAR.*'; SqlType = 'VARCHAR'; UsesPrecision = $true; DefaultPrecision = '255' }
        # ... etc
    }

    DotNetTypeMappings = @{
        'DATE' = [System.DateTime]
        'DATETIME' = [System.DateTime]
        # ... etc
    }

    NullRepresentations = @(
        'NULL', 'NA', 'N/A', '', ' '
    )

    BooleanMappings = @{
        True = @('1', 'TRUE', 'YES', 'Y', 'T')
        False = @('0', 'FALSE', 'NO', 'N', 'F')
    }
}
```

#### 1.3 Create Common Utilities Module
**File:** `Import-DATFile.Common.psm1`

Functions to include:
- `Initialize-ImportModules` - Module loading with error handling
- `New-SqlConnectionString` - Connection string builder
- `Get-DatabaseNameFromConnectionString` - Extract DB name
- `Test-ImportPath` - Standardized path validation
- `ConvertTo-TypedValue` - Type conversion dispatcher
- `New-ImportDataTable` - DataTable creation
- `Read-DatFileLines` - File reading with multi-line support

### Phase 2: Core Module Refactoring

#### 2.1 Break Down Import-DataFile

**New structure:**
```powershell
function Import-DataFile {
    # Thin orchestrator
    $lines = Read-DatFileLines -FilePath $FilePath
    $dataTable = New-ImportDataTable -Fields $Fields
    $populatedTable = Add-DataTableRows -DataTable $dataTable -Lines $lines -Fields $Fields
    $rowCount = Invoke-SqlBulkCopy -DataTable $populatedTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $TableName
    return $rowCount
}

function Read-DatFileLines { ... }
function New-ImportDataTable { ... }
function Add-DataTableRows { ... }
function Invoke-SqlBulkCopy { ... }
```

#### 2.2 Improve Logging Strategy

**Changes:**
- Replace Write-ImportLog VERBOSE calls with Write-Verbose
- Replace Write-ImportLog DEBUG calls with Write-Debug
- Replace Write-ImportLog WARNING calls with Write-Warning
- Replace Write-ImportLog ERROR calls with Write-Error
- Keep Write-ImportLog for INFO and SUCCESS only (or use Write-Information)

#### 2.3 Add Parameter Validation

**Example:**
```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$DataFolder,

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-zA-Z0-9_]+$')]
    [string]$SchemaName
)
```

### Phase 3: CLI and GUI Updates

#### 3.1 Refactor Import-CLI.ps1
- Extract Get-DatabaseConnection to Common module
- Use common validation functions
- Simplify module loading

#### 3.2 Refactor Import-GUI.ps1
- Use common connection string builder
- Share validation logic
- Simplify module loading

### Phase 4: Documentation and Testing

#### 4.1 Add Comment-Based Help
Add comprehensive help to:
- All exported functions
- All public helper functions
- Include SYNOPSIS, DESCRIPTION, PARAMETERS, EXAMPLES, NOTES

#### 4.2 Update CLAUDE.md
Document:
- New modular structure
- Type mapping extensibility
- Constants configuration
- Testing patterns

## Implementation Order

1. ✓ Create REFACTORING_ANALYSIS.md (this document)
2. Create Import-DATFile.Constants.ps1
3. Create TypeMappings.psd1
4. Create Import-DATFile.Common.psm1
5. Refactor SqlServerDataImport.psm1 (breaking down functions)
6. Update Import-CLI.ps1
7. Update Import-GUI.ps1
8. Add comprehensive help documentation
9. Update CLAUDE.md
10. Create test validation script
11. Commit changes

## Benefits

### Code Quality
- **Reduced duplication:** ~30% reduction in duplicate code
- **Improved testability:** Smaller, focused functions easier to test
- **Better maintainability:** Single source of truth for common operations
- **Enhanced readability:** Functions do one thing well

### Extensibility
- **Easy to add types:** Modify configuration file, not code
- **Custom converters:** Register new type converters without core changes
- **Configuration-driven:** Change behavior without code changes

### Consistency
- **Uniform error handling:** Consistent error messages
- **Standardized logging:** Predictable output format
- **Shared validation:** Same validation rules everywhere

## Risks and Mitigations

### Risk 1: Breaking Changes
**Mitigation:** Keep all public function signatures unchanged. Only internals change.

### Risk 2: Performance Impact
**Mitigation:** Minimal - function call overhead is negligible compared to I/O operations

### Risk 3: Increased Complexity
**Mitigation:** Better organization actually reduces cognitive load despite more files

## Success Criteria

- [ ] All existing functionality preserved
- [ ] No changes to public API (exported functions)
- [ ] All TODOs completed
- [ ] Code passes basic validation (syntax check)
- [ ] Documentation updated
- [ ] Commit with clear message

## Notes

This refactoring maintains backward compatibility while significantly improving code quality, maintainability, and extensibility. The modular approach follows PowerShell best practices and makes the codebase easier to understand and extend.
