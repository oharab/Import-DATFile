# SQL Server Data Import Utility

A powerful PowerShell script that imports pipe-separated `.dat` files into SQL Server databases using Excel specifications for table schema definitions.

## 🚀 Quick Start

### 🖱️ Easy GUI Method (Recommended for most users)
1. **Double-click** `Launch-Import-GUI.bat`
2. **Use the friendly interface** to select your data folder and Excel file
3. **Configure database connection** in the GUI
4. **Optional:** Check **"Validate Only"** to test data without importing
5. **Click "Start Import"** and watch the progress!

### ⌨️ Command Line Method (For advanced users)
1. **Install Prerequisites**
   ```powershell
   Install-Module -Name SqlServer
   Install-Module -Name ImportExcel
   ```

2. **Prepare Your Data**
   - Place your `.dat` files in a folder (must include `*Employee.dat` for prefix detection)
   - Create an Excel specification file (`ExportSpec.xlsx`) with table/field definitions
   - **Important:** Every .dat file MUST have ImportID as the first field

3. **Run the Import**
   ```powershell
   # Interactive mode (prompts for all inputs)
   .\Import-CLI.ps1

   # Windows Authentication
   .\Import-CLI.ps1 -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB"

   # SQL Authentication
   .\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -Username "sa" -Password "YourPassword"

   # Validate data without database import (no SQL Server connection required)
   .\Import-CLI.ps1 -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -ValidateOnly

   # Specify schema name without prompts
   .\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -SchemaName "MySchema"

   # Force mode (drops/recreates all tables - DELETES existing data!)
   .\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -Force

   # Dry run (preview without making changes)
   .\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -WhatIf

   # Verbose logging for troubleshooting
   .\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -Verbose
   ```

The script will guide you through the configuration process!

## 📁 What You Need

### Data Files Structure
```
your-data-folder/
├── PrefixEmployee.dat      # Required for prefix detection
├── PrefixDepartment.dat    # Additional data files
├── PrefixProject.dat       # All files share same prefix
└── ExportSpec.xlsx         # Table specifications
```

### Excel Specification Format
Your Excel file should contain these columns:
- **Table name**: Target SQL table name (e.g., "Employee", "Department")
- **Column name**: Column name in the table
- **Data type**: SQL data type (VARCHAR, INT, DATETIME, etc.)
- **Precision**: Optional size/precision (e.g., "50" for VARCHAR(50))

## ✨ Key Features

- 🔍 **Automatic Prefix Detection** - Finds your data prefix from Employee.dat file
- ✅ **Validation Mode** - Validate data files and Excel specs without SQL Server connection
- 🎛️ **Interactive Configuration** - Prompts for all necessary settings
- ⚡ **High-Performance Import** - Uses SqlBulkCopy for lightning-fast imports
- 🛡️ **Smart Field Handling** - Automatically handles extra import name fields
- 📊 **Import Summary** - Shows exactly what was imported and row counts
- 📝 **Comprehensive Logging** - Detailed progress tracking with verbose mode
- 🔄 **Error Recovery** - Handles table conflicts and data issues gracefully
- 🧩 **Modular Architecture** - Clean separation between core logic and user interfaces

## 🏗️ Architecture

The project uses a **Private/Public module structure** following PowerShell best practices:

```
📁 Project Structure
├── 📦 SqlServerDataImport.psm1          # Root module loader
├── 📦 SqlServerDataImport.psd1          # Module manifest
│
├── 📁 Public/                            # Exported functions (1 function)
│   └── Invoke-SqlServerDataImport.ps1
│
├── 📁 Private/                           # Internal implementation (40 functions)
│   ├── Database/                         # Database operations (9 functions)
│   ├── DataImport/                       # Import pipeline (14 functions)
│   ├── Initialization/                   # Module setup (1 function)
│   ├── Logging/                          # Logging & summary (4 functions)
│   ├── Orchestration/                    # Workflow coordination (5 functions)
│   ├── PostInstall/                      # Post-import scripts (1 function)
│   ├── Specification/                    # Excel/file processing (3 functions)
│   └── Validation/                       # Input validation (2 functions)
│
├── 🖥️ Import-GUI.ps1                    # Windows Forms GUI
├── ⌨️ Import-CLI.ps1                     # Command-line interface
├── 🚀 Launch-Import-GUI.bat             # One-click GUI launcher
├── 📚 README.md                         # User documentation
└── 🔧 CLAUDE.md                         # Developer/AI guidance
```

**Benefits:**
- **Clear API**: Only `Invoke-SqlServerDataImport` is exported
- **Better Organization**: 40 functions grouped by concern (Database, DataImport, Orchestration, etc.)
- **Easy Testing**: Each function independently testable
- **Maintainability**: Smaller, focused files (~100 lines each)

## 🎯 Usage Examples

### 🖥️ GUI Interface (Easiest)
1. **Double-click** `Launch-Import-GUI.bat`
2. **Select** your data folder using the Browse button
3. **Choose** your Excel specification file
4. **Configure options**:
   - **Validate Only** - Check this to validate data files without importing (no SQL Server required)
   - **Verbose Logging** - Show detailed operational information
   - **Table exists action** - Choose Recreate, Truncate, or Skip
5. **Click "Start Import"** (or "Start Validation" if Validate Only is checked)
6. **Monitor progress** in real-time via the output window

![GUI Interface Features](gui-preview.png)
*User-friendly interface with file browsers, progress tracking, and real-time output*

### ⌨️ Command Line Interface

#### Basic Usage (Interactive)
```powershell
.\Import-CLI.ps1
```
The script will prompt you for:
- Data folder location (defaults to current directory)
- Excel specification file name (defaults to "ExportSpec.xlsx")
- Database connection details
- Schema name (defaults to detected prefix)

#### Non-Interactive with Parameters
```powershell
# Fully automated (no prompts)
.\Import-CLI.ps1 -DataFolder "C:\MyData" -ExcelSpecFile "MySpecs.xlsx" -Server "localhost" -Database "MyDB" -SchemaName "dbo"
```

#### Validation Only (No Database Required)
```powershell
.\Import-CLI.ps1 -DataFolder "C:\MyData" -ExcelSpecFile "MySpecs.xlsx" -Server "localhost" -Database "MyDB" -ValidateOnly
```

#### With Verbose Logging
```powershell
.\Import-CLI.ps1 -Verbose
```

## 📋 Data Type Support

The script automatically maps Excel types to SQL Server types:

| Excel Type | SQL Server Type | Example |
|------------|-----------------|---------|
| VARCHAR    | VARCHAR(n)      | VARCHAR(50) |
| INT        | INT             | Employee ID |
| MONEY      | MONEY           | Salary amounts |
| DATETIME   | DATETIME2       | Hire dates |
| DECIMAL    | DECIMAL(p,s)    | DECIMAL(10,2) |
| BIT        | BIT             | Active flags |

*Unknown types default to NVARCHAR(255) with a warning*

## 🔧 Configuration Options

### Available Parameters
- `-DataFolder`: Path to .dat files and Excel spec
- `-ExcelSpecFile`: Specification file (default: "ExportSpec.xlsx")
- `-Server`, `-Database`: SQL Server connection details
- `-Username`, `-Password`: SQL auth (omit for Windows auth)
- `-SchemaName`: Custom schema name (default: detected prefix)
- `-ValidateOnly`: Validate data files without importing (no SQL Server connection required)
- `-Force`: Auto-recreate tables (⚠️ DELETES existing data)
- `-PostInstallScripts`: Path to .sql files to execute after import
- `-Verbose`: Detailed logging for troubleshooting
- `-WhatIf`: Preview without making changes (dry run)

### Database Authentication
- **Windows Authentication** (recommended) - Omit `-Username` parameter
- **SQL Server Authentication** - Provide `-Username` and optionally `-Password`

### Table Conflict Resolution
When tables already exist, you have these options:

**CLI (Interactive Mode):**
1. **Cancel** - Stop the entire import
2. **Skip** - Skip this table only
3. **Truncate** - Clear existing data
4. **Recreate** - Drop and recreate table

**GUI:**
- Choose **Recreate**, **Truncate**, or **Skip** from dropdown before starting

**Both CLI & GUI:**
- Use `-Force` parameter to automatically recreate ALL tables (⚠️ DELETES data!)

### Post-Install Scripts
Execute custom SQL after import completes (views, procedures, indexes, etc.):
- Create `.sql` files with `{{DATABASE}}` and `{{SCHEMA}}` placeholders
- Scripts execute alphabetically with 300-second timeout
- Example: `.\Import-CLI.ps1 -DataFolder "C:\Data" -Server "localhost" -Database "MyDB" -PostInstallScripts "C:\Scripts"`

## 📈 Performance

### Optimized for Large Datasets
- **SqlBulkCopy ONLY** - No INSERT fallbacks for maximum speed
- **~67% faster** than original implementation
- **Minimal memory usage** with optimized DataTable structures
- **Fail-fast validation** for quick error detection

### Performance Benchmark
- **1M rows**: ~40 seconds (was 2 minutes in original version)
- **100K rows**: ~5 seconds
- **10K rows**: ~1 second

### Data Format Requirements
For optimal performance, ensure data follows these formats:
- **Dates**: `yyyy-MM-dd HH:mm:ss.fff` (or variations: .ff, .f, no milliseconds, date-only)
- **Decimals**: Period as separator, no thousands separator (e.g., `123.45` not `123,45`)
- **Integers**: Can include decimal notation (e.g., `123.0` converts to 123)
- **Boolean**: `1/0`, `TRUE/FALSE`, `YES/NO`, `Y/N`, `T/F` (case insensitive)
- **NULL**: Empty string, whitespace, `NULL`, `NA`, `N/A` (case insensitive)

## 🔍 Validation Mode

Before importing to a live database, you can validate your data files and Excel specification without requiring a SQL Server connection.

### When to Use Validation Mode
- ✅ **Pre-flight check** - Verify data structure before production import
- ✅ **No SQL Server access** - Test data files on machines without database access
- ✅ **Excel spec verification** - Confirm table and field specifications are correct
- ✅ **Data quality checks** - Identify type conversion issues early
- ✅ **Field count validation** - Ensure ImportID and all expected fields are present

### Using Validation Mode

**CLI:**
```powershell
.\Import-CLI.ps1 -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -ValidateOnly
```

**GUI:**
1. Check the **"Validate Only (no DB import)"** checkbox
2. Click **"Start Import"** to run validation
3. Review validation results in the output window

### What Gets Validated
- ✅ Excel specification structure (required columns, data types)
- ✅ Data file existence and format
- ✅ Field count matching (ImportID + specification fields)
- ✅ Data type conversions (dates, numbers, booleans)
- ✅ Multi-line field handling
- ❌ **NOT validated**: Database connectivity, table existence, SQL permissions

**Note:** Server and Database parameters are still required but no actual connection is made during validation.

## 📊 Import Summary

After completion, you'll see a detailed summary:

```
=== Import Summary ===

Imported Tables:
Schema: ACME2024
==================================================

Table Name                          Rows Imported
[ACME2024].[Employee]                      1,234
[ACME2024].[Department]                       45
[ACME2024].[Project]                         189

==================================================
Total Tables Imported: 3
Total Rows Imported: 1,468
```

## 🐛 Troubleshooting

### 🖥️ GUI Interface Issues

**GUI won't start**
- Right-click `Launch-Import-GUI.bat` and "Run as Administrator"
- Ensure PowerShell execution policy allows scripts
- Install required PowerShell modules (SqlServer, ImportExcel)

**Browse buttons don't work**
- Type paths manually if file dialogs fail
- Ensure you have read permissions to the folders

### 📂 Common Data Issues

**"No *Employee.dat file found"**
- Ensure you have at least one file ending in `Employee.dat`
- This file is used to detect the data prefix

**"Excel specification file not found"**
- Check the file name and location
- Default looks for `ExportSpec.xlsx` in the data folder

**"Field count mismatch"**
- **CRITICAL:** Every .dat file MUST have ImportID as the first field
- Expected field count = 1 (ImportID) + number of fields in Excel specification
- Import will fail immediately if field counts don't match exactly

**"Multi-line fields detected"**
- Fields can contain embedded newlines (CR/LF) - this is fully supported
- Parser automatically accumulates lines until expected field count is reached
- Embedded newlines are preserved in the data

**Type conversion warnings**
- Check data format matches requirements (see Performance section)
- Common issues: comma decimal separator, invalid date format
- Review console output for specific conversion failures

### 🔧 Getting Help

**Validate First:** Always start by running in validation mode to catch data issues:
```powershell
.\Import-CLI.ps1 -DataFolder "C:\Data" -ExcelSpecFile "Spec.xlsx" -Server "localhost" -Database "MyDB" -ValidateOnly
```

**GUI Method:** Check the output window for detailed error messages

**Command Line Method:** Run with verbose logging for detailed diagnostics:
```powershell
.\Import-CLI.ps1 -Verbose
```

**Module Method:** For custom scripts, import the module directly:
```powershell
Import-Module .\SqlServerDataImport.psm1
Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "Spec.xlsx" -Server "localhost" -Database "MyDB" -SchemaName "dbo" -ValidateOnly
```

## 📄 Requirements

### For Data Import:
- **PowerShell 5.1** or later
- **SQL Server** (any supported version)
- **SqlServer PowerShell Module**
- **ImportExcel PowerShell Module**
- **Network access** to target SQL Server instance

### For Validation Only Mode:
- **PowerShell 5.1** or later
- **ImportExcel PowerShell Module**
- ❌ **SQL Server NOT required** (validation runs without database connection)

## 🔒 Security Notes

- Connection strings are handled securely
- No credentials are logged or stored
- Uses parameterized queries to prevent SQL injection
- Excel files may contain sensitive schema information (excluded from git)

## 📚 Additional Documentation

See `CLAUDE.md` for detailed technical documentation including:
- Architecture overview
- Function reference
- Logging system details
- Development guidelines

---

## 🤝 Contributing

This script is designed to be self-contained and easily customizable. Feel free to modify for your specific needs!

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Run with `-Verbose` for detailed logging
3. Review the `CLAUDE.md` technical documentation