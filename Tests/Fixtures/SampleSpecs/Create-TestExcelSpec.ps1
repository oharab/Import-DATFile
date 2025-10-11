# Create-TestExcelSpec.ps1
# Script to generate test Excel specification file

# Requires ImportExcel module
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Warning "ImportExcel module not found. Please install: Install-Module ImportExcel"
    exit 1
}

Import-Module ImportExcel

$specData = @(
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'FirstName'
        'Data type' = 'VARCHAR'
        'Precision' = '50'
    },
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'LastName'
        'Data type' = 'VARCHAR'
        'Precision' = '50'
    },
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'BirthDate'
        'Data type' = 'DATE'
        'Precision' = ''
    },
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'Department'
        'Data type' = 'VARCHAR'
        'Precision' = '100'
    },
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'Salary'
        'Data type' = 'DECIMAL'
        'Precision' = '10,2'
    },
    [PSCustomObject]@{
        'Table name' = 'Employee'
        'Column name' = 'IsActive'
        'Data type' = 'BIT'
        'Precision' = ''
    },
    [PSCustomObject]@{
        'Table name' = 'Department'
        'Column name' = 'DeptName'
        'Data type' = 'VARCHAR'
        'Precision' = '100'
    },
    [PSCustomObject]@{
        'Table name' = 'Department'
        'Column name' = 'Location'
        'Data type' = 'VARCHAR'
        'Precision' = '50'
    },
    [PSCustomObject]@{
        'Table name' = 'Department'
        'Column name' = 'Description'
        'Data type' = 'VARCHAR'
        'Precision' = '500'
    },
    [PSCustomObject]@{
        'Table name' = 'Department'
        'Column name' = 'EmployeeCount'
        'Data type' = 'INT'
        'Precision' = ''
    }
)

$excelPath = Join-Path $PSScriptRoot "TestExportSpec.xlsx"

$specData | Export-Excel -Path $excelPath -WorksheetName "Sheet1" -AutoSize -ClearSheet

Write-Host "Created test Excel specification: $excelPath" -ForegroundColor Green
