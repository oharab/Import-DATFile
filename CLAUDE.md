# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell-based data import utility that reads pipe-separated .dat files and imports them into SQL Server databases. The system uses an Excel specification file (`ExportSpec.xlsx`) to define table schemas and field mappings.

## Core Architecture

### Single Script Design
- **Import-DATFile.ps1**: Main script containing all functionality
- Self-contained with no external PowerShell modules beyond SqlServer and ImportExcel

### Key Components
1. **Prefix Detection**: Automatically detects file prefix by finding `*Employee.dat` file
2. **Schema Management**: Creates database schemas based on detected prefix
3. **Dynamic Table Creation**: Builds SQL tables from Excel specifications
4. **Batch Data Import**: Processes pipe-separated data files in 1000-row batches
5. **Interactive Configuration**: Prompts for data folder, Excel file, database connection and schema details

### Data Flow
1. Script detects prefix from Employee.dat file presence
2. Reads table/field specifications from Excel file
3. Establishes SQL Server connection (Windows or SQL auth)
4. Creates schema and tables based on specifications
5. Imports data from matching .dat files in batches
6. Displays comprehensive import summary with row counts

## Running the Script

### Basic Execution (Interactive Mode)
```powershell
.\Import-DATFile.ps1
```
When run without parameters, the script prompts for:
- **Data Folder**: Defaults to current location (Get-Location)
- **Excel Specification File**: Defaults to "ExportSpec.xlsx"

### With Parameters
```powershell
.\Import-DATFile.ps1 -DataFolder "C:\path\to\data" -ExcelSpecFile "CustomSpec.xlsx"
```

### With Verbose Logging
```powershell
.\Import-DATFile.ps1 -Verbose
.\Import-DATFile.ps1 -DataFolder "C:\path\to\data" -ExcelSpecFile "CustomSpec.xlsx" -Verbose
```

### Prerequisites
```powershell
Install-Module -Name SqlServer
Install-Module -Name ImportExcel
```

## File Structure Requirements

### Expected Data Files
- At least one `*Employee.dat` file (used for prefix detection)
- Additional `.dat` files with same prefix
- `ExportSpec.xlsx` with table specifications

### Excel Specification Format
Required columns in Excel file:
- `Table name`: Target SQL table name
- `Field name`: Column name
- `Field type`: SQL data type
- `Precision`: Type precision/length (optional)

## Data Type Mappings

The script maps Excel types to SQL Server types via `Get-DataTypeMapping` function:
- VARCHAR/CHAR with precision support
- Numeric types (INT, BIGINT, DECIMAL, MONEY)
- Date/time types (DATE, DATETIME2, TIME)
- Text types default to NVARCHAR(MAX)
- Unknown types default to NVARCHAR(255)

## Error Handling & Recovery

### Table Conflict Resolution
When tables exist, the script offers interactive options:
1. Cancel entire script
2. Skip individual table
3. Truncate existing data
4. Drop and recreate table

### Field Count Mismatch Handling
Data files often contain an extra first field (import name) not in specifications:
- Automatically detects when data file has exactly one more field than spec
- Interactive prompt offers three options:
  1. **Yes**: Skip first field for current table only
  2. **No**: Exit the entire import process
  3. **Always**: Skip first field for all remaining tables without asking
- Global `$AlwaysSkipFirstField` variable tracks "Always" selection

### Validation Steps
- Verifies data folder and Excel file existence
- Tests database connectivity before processing
- Validates unique Employee.dat file for prefix detection
- Checks for field specifications per table
- Validates field count alignment between data files and specifications

## Logging System

### Standard Logging
All operations include timestamped logging with different levels:
- **INFO**: General operation progress
- **SUCCESS**: Successful completions
- **WARNING**: Non-critical issues
- **ERROR**: Critical failures

### Verbose Logging
Use `-Verbose` parameter for detailed diagnostic information:
- Field count analysis and validation details
- SQL query execution details
- Batch processing statistics
- File size and processing metrics
- Configuration and parameter details

### Log Format
```
[2024-01-15 14:30:25] [INFO] Starting SQL Server Data Import Script
[2024-01-15 14:30:26] [VERBOSE] Using provided parameters - DataFolder: C:\data
[2024-01-15 14:30:27] [SUCCESS] Configuration completed
```

## Import Summary

After all imports complete, the script automatically displays a comprehensive summary:
- **Table List**: All successfully imported tables with schema qualification
- **Row Counts**: Number of rows imported per table with thousand separators
- **Totals**: Total number of tables and total rows imported
- **Formatted Display**: Clean tabular output for easy review

### Example Summary Output
```
=== Import Summary ===

Imported Tables:
Schema: ACME2024

Table Name                          Rows Imported
[ACME2024].[Employee]                      1,234
[ACME2024].[Department]                       45
[ACME2024].[Project]                         189

Total Tables Imported: 3
Total Rows Imported: 1,468
```

## Development Notes

- Batch processing prevents memory issues with large datasets
- SQL injection protection via parameter escaping
- Comprehensive error handling with graceful degradation
- Interactive prompts for critical decisions
- Detailed progress reporting during import process
- Comprehensive logging with verbose mode for troubleshooting
- Automatic import summary with detailed statistics