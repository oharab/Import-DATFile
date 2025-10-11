# Test Fixtures

This directory contains sample data files and specifications for testing.

## Setup

### Generate Excel Specification File

To create the test Excel specification file:

```powershell
# Ensure ImportExcel module is installed
Install-Module -Name ImportExcel -Force

# Generate the test Excel file
.\SampleSpecs\Create-TestExcelSpec.ps1
```

This will create `TestExportSpec.xlsx` in the `SampleSpecs` folder.

## Sample Data Files

### SampleData/TestEmployee.dat
Simple employee data with standard fields (no multi-line records).

### SampleData/TestDepartment.dat
Department data including a multi-line record to test multi-line parsing logic.

## File Structure

```
Fixtures/
├── SampleData/
│   ├── TestEmployee.dat       # Employee test data
│   └── TestDepartment.dat     # Department test data (with multi-line)
└── SampleSpecs/
    ├── Create-TestExcelSpec.ps1    # Script to generate Excel
    └── TestExportSpec.xlsx         # Generated Excel spec (gitignored)
```

## Usage in Tests

```powershell
BeforeAll {
    $testDataFolder = Join-Path $PSScriptRoot "..\Fixtures\SampleData"
    $testSpecFile = Join-Path $PSScriptRoot "..\Fixtures\SampleSpecs\TestExportSpec.xlsx"
}
```
