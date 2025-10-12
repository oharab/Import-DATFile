# Invoke-SqlServerDataImport.Integration.Tests.ps1
# Integration tests for full import workflow
#
# Two test contexts:
# 1. DataTable-based (always runs) - Tests workflow with mocked database operations
# 2. Real SQL Server (optional) - Tests with real SQL Server, auto-skips if unavailable

BeforeAll {
    # Import the main module
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Import test helpers
    $testHelpersPath = Join-Path $PSScriptRoot "..\..\TestHelpers\DatabaseHelpers.ps1"
    Import-Module $testHelpersPath -Force

    # Check SQL Server availability for optional tests
    $script:HasSqlServer = Test-SqlServerAvailable -ServerName "localhost"
    $script:HasLocalDb = Test-LocalDbAvailable

    # Create test data directory
    $script:TestDataFolder = Join-Path $TestDrive "ImportData"
    New-Item -ItemType Directory -Path $script:TestDataFolder -Force | Out-Null

    # Helper function to create test Excel file
    function New-TestExcelSpec {
        param([string]$Path, [string]$Prefix)

        $excelPath = Join-Path $Path "TestSpec.xlsx"

        # Create simple Excel spec with Import-Excel module
        $spec = @(
            [PSCustomObject]@{
                'Table name' = 'Employee'
                'Column name' = 'FirstName'
                'Data type' = 'VARCHAR'
                'Precision' = 50
            },
            [PSCustomObject]@{
                'Table name' = 'Employee'
                'Column name' = 'LastName'
                'Data type' = 'VARCHAR'
                'Precision' = 50
            },
            [PSCustomObject]@{
                'Table name' = 'Employee'
                'Column name' = 'HireDate'
                'Data type' = 'DATETIME'
                'Precision' = $null
            }
        )

        $spec | Export-Excel -Path $excelPath -WorksheetName "Sheet1" -AutoSize
        return $excelPath
    }

    # Helper function to create test DAT file
    function New-TestDatFile {
        param(
            [string]$Path,
            [string]$Prefix,
            [string]$TableName,
            [int]$RecordCount = 3
        )

        $datPath = Join-Path $Path "$Prefix$TableName.dat"
        $records = @()

        for ($i = 1; $i -le $RecordCount; $i++) {
            $records += "EMP$($i.ToString('000'))|FirstName$i|LastName$i|2024-01-$($i.ToString('00')) 10:00:00"
        }

        Set-Content -Path $datPath -Value $records
        return $datPath
    }
}

Describe "Invoke-SqlServerDataImport - Integration Tests" {

    Context "DataTable-based Workflow (No SQL Server Required)" {
        BeforeEach {
            # Create test data
            $testPrefix = "TEST_"
            $testExcel = New-TestExcelSpec -Path $script:TestDataFolder -Prefix $testPrefix
            $testDat = New-TestDatFile -Path $script:TestDataFolder -Prefix $testPrefix -TableName "Employee" -RecordCount 5

            # Mock all database operations
            Mock Test-DatabaseConnection { return $true } -ModuleName SqlServerDataImport
            Mock New-DatabaseSchema { } -ModuleName SqlServerDataImport
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Clear-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Remove-DatabaseTable { } -ModuleName SqlServerDataImport

            # Mock SqlBulkCopy to capture DataTable and return row count
            Mock Invoke-SqlBulkCopy {
                param($DataTable, $ConnectionString, $SchemaName, $TableName)

                # Store DataTable for inspection
                $script:CapturedDataTable = $DataTable

                # Return row count
                return $DataTable.Rows.Count
            } -ModuleName SqlServerDataImport
        }

        It "Should complete full import workflow with mocked database" {
            # Arrange
            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterThan 0
            $result[0].TableName | Should -Be "Employee"
            $result[0].RowCount | Should -Be 5

            # Verify mocks were called
            Should -Invoke Test-DatabaseConnection -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Invoke-SqlBulkCopy -Times 1 -ModuleName SqlServerDataImport
        }

        It "Should create DataTable with correct structure" {
            # Arrange
            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Check captured DataTable structure
            $script:CapturedDataTable | Should -Not -BeNullOrEmpty
            $script:CapturedDataTable.Columns.Count | Should -Be 4  # ImportID + 3 fields
            $script:CapturedDataTable.Columns["ImportID"] | Should -Not -BeNullOrEmpty
            $script:CapturedDataTable.Columns["FirstName"] | Should -Not -BeNullOrEmpty
            $script:CapturedDataTable.Columns["LastName"] | Should -Not -BeNullOrEmpty
            $script:CapturedDataTable.Columns["HireDate"] | Should -Not -BeNullOrEmpty

            # Check data types
            $script:CapturedDataTable.Columns["ImportID"].DataType | Should -Be ([string])
            $script:CapturedDataTable.Columns["FirstName"].DataType | Should -Be ([string])
            $script:CapturedDataTable.Columns["HireDate"].DataType | Should -Be ([DateTime])
        }

        It "Should populate DataTable with correct values" {
            # Arrange
            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Check first row data
            $firstRow = $script:CapturedDataTable.Rows[0]
            $firstRow["ImportID"] | Should -Be "EMP001"
            $firstRow["FirstName"] | Should -Be "FirstName1"
            $firstRow["LastName"] | Should -Be "LastName1"
            $firstRow["HireDate"] | Should -BeOfType [DateTime]
        }

        It "Should handle TableExistsAction=Skip" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Verify import was skipped
            Should -Invoke Test-TableExists -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Invoke-SqlBulkCopy -Times 0 -ModuleName SqlServerDataImport
        }

        It "Should handle TableExistsAction=Truncate" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Truncate"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Verify truncate was called
            Should -Invoke Clear-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Invoke-SqlBulkCopy -Times 1 -ModuleName SqlServerDataImport
        }

        It "Should handle TableExistsAction=Recreate" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $script:TestDataFolder
                ExcelSpecFile = "TestSpec.xlsx"
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Recreate"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Verify drop and create were called
            Should -Invoke Remove-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke New-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Invoke-SqlBulkCopy -Times 1 -ModuleName SqlServerDataImport
        }
    }

    Context "Real SQL Server Tests (Optional)" {
        BeforeAll {
            # Determine which SQL Server is available
            if (-not $script:HasSqlServer -and -not $script:HasLocalDb) {
                Set-ItResult -Skipped -Because "No SQL Server available (neither localhost nor LocalDB)"
            }
        }

        It "Should import data to real SQL Server" -Skip:(-not ($script:HasSqlServer -or $script:HasLocalDb)) {
            # Arrange - Create test database
            if ($script:HasLocalDb) {
                $testDb = Initialize-TestDatabase
                $server = $testDb.ConnectionString -replace ".*Server=([^;]+).*", '$1'
                $database = $testDb.DatabaseName
            }
            else {
                # Use localhost SQL Server with temp database
                $database = "ImportTest_$(Get-Random -Minimum 10000 -Maximum 99999)"
                $server = "localhost"
                $connString = "Server=$server;Database=master;Integrated Security=True;"
                Invoke-Sqlcmd -ConnectionString $connString -Query "CREATE DATABASE [$database]"
            }

            # Create test data
            $testPrefix = "REAL_"
            $testDataPath = Join-Path $TestDrive "RealTest"
            New-Item -ItemType Directory -Path $testDataPath -Force | Out-Null

            $testExcel = New-TestExcelSpec -Path $testDataPath -Prefix $testPrefix
            $testDat = New-TestDatFile -Path $testDataPath -Prefix $testPrefix -TableName "Employee" -RecordCount 10

            try {
                # Act
                $params = @{
                    DataFolder = $testDataPath
                    ExcelSpecFile = "TestSpec.xlsx"
                    Server = $server
                    Database = $database
                    SchemaName = "dbo"
                    TableExistsAction = "Recreate"
                }

                $result = Invoke-SqlServerDataImport @params

                # Assert
                $result | Should -Not -BeNullOrEmpty
                $result[0].TableName | Should -Be "Employee"
                $result[0].RowCount | Should -Be 10

                # Verify data in database
                $connString = "Server=$server;Database=$database;Integrated Security=True;"
                $query = "SELECT COUNT(*) AS RowCount FROM [dbo].[Employee]"
                $count = Invoke-Sqlcmd -ConnectionString $connString -Query $query
                $count.RowCount | Should -Be 10

                # Verify schema
                $query = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Employee' ORDER BY ORDINAL_POSITION"
                $columns = Invoke-Sqlcmd -ConnectionString $connString -Query $query
                $columns.Count | Should -Be 4  # ImportID + 3 fields
                $columns[0].COLUMN_NAME | Should -Be "ImportID"
                $columns[1].COLUMN_NAME | Should -Be "FirstName"
            }
            finally {
                # Cleanup
                if ($script:HasLocalDb) {
                    Remove-TestDatabase -DatabaseName $testDb.DatabaseName
                }
                else {
                    $connString = "Server=$server;Database=master;Integrated Security=True;"
                    Invoke-Sqlcmd -ConnectionString $connString -Query "DROP DATABASE [$database]" -ErrorAction SilentlyContinue
                }
            }
        }

        It "Should handle real TableExistsAction=Truncate" -Skip:(-not ($script:HasSqlServer -or $script:HasLocalDb)) {
            # Similar structure to previous test but tests Truncate action
            # Arrange - Create test database and initial data
            if ($script:HasLocalDb) {
                $testDb = Initialize-TestDatabase
                $server = $testDb.ConnectionString -replace ".*Server=([^;]+).*", '$1'
                $database = $testDb.DatabaseName
            }
            else {
                $database = "ImportTest_$(Get-Random -Minimum 10000 -Maximum 99999)"
                $server = "localhost"
                $connString = "Server=$server;Database=master;Integrated Security=True;"
                Invoke-Sqlcmd -ConnectionString $connString -Query "CREATE DATABASE [$database]"
            }

            $testPrefix = "TRUNC_"
            $testDataPath = Join-Path $TestDrive "TruncateTest"
            New-Item -ItemType Directory -Path $testDataPath -Force | Out-Null

            $testExcel = New-TestExcelSpec -Path $testDataPath -Prefix $testPrefix
            $testDat = New-TestDatFile -Path $testDataPath -Prefix $testPrefix -TableName "Employee" -RecordCount 5

            try {
                # First import - create table
                $params = @{
                    DataFolder = $testDataPath
                    ExcelSpecFile = "TestSpec.xlsx"
                    Server = $server
                    Database = $database
                    SchemaName = "dbo"
                    TableExistsAction = "Recreate"
                }
                $result1 = Invoke-SqlServerDataImport @params

                # Create new DAT file with different data
                $testDat = New-TestDatFile -Path $testDataPath -Prefix $testPrefix -TableName "Employee" -RecordCount 8

                # Second import - truncate and reload
                $params.TableExistsAction = "Truncate"
                $result2 = Invoke-SqlServerDataImport @params

                # Assert - Should have 8 rows (not 5+8=13)
                $connString = "Server=$server;Database=$database;Integrated Security=True;"
                $query = "SELECT COUNT(*) AS RowCount FROM [dbo].[Employee]"
                $count = Invoke-Sqlcmd -ConnectionString $connString -Query $query
                $count.RowCount | Should -Be 8
            }
            finally {
                # Cleanup
                if ($script:HasLocalDb) {
                    Remove-TestDatabase -DatabaseName $testDb.DatabaseName
                }
                else {
                    $connString = "Server=$server;Database=master;Integrated Security=True;"
                    Invoke-Sqlcmd -ConnectionString $connString -Query "DROP DATABASE [$database]" -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
