# Invoke-TableImportProcess.Tests.ps1
# Unit tests for Invoke-TableImportProcess function

# Import module at script scope (required for InModuleScope)
$moduleRoot = Join-Path $PSScriptRoot "..\..\..\.."
$modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
Import-Module $modulePath -Force

InModuleScope SqlServerDataImport {
    Describe "Invoke-TableImportProcess" {

    Context "Successful Table Import" {
        BeforeEach {
            # Create test DAT file
            $testFile = Join-Path $TestDrive "TEST_Employee.dat"
            "EMP001|John|Doe" | Set-Content $testFile

            $fileInfo = Get-Item $testFile

            $tableSpecs = @(
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'LastName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            )

            # Mock all dependencies
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 100 } -ModuleName SqlServerDataImport
            Mock Add-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should return result with table name and row count" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Skip"

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.TableName | Should -Be "Employee"
            $result.RowsImported | Should -Be 100
            $result.Skipped | Should -Be $false
        }

        It "Should create table when it does not exist" {
            # Arrange
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Skip"

            # Assert
            Should -Invoke New-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
        }

        It "Should add import summary entry" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Skip"

            # Assert
            Should -Invoke Add-ImportSummary -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $TableName -eq "Employee" -and $RowCount -eq 100
            }
        }
    }

    Context "TableExistsAction - Skip" {
        BeforeEach {
            $testFile = Join-Path $TestDrive "TEST_Employee.dat"
            "EMP001|John|Doe" | Set-Content $testFile
            $fileInfo = Get-Item $testFile

            $tableSpecs = @(
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            )

            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Clear-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Remove-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 100 } -ModuleName SqlServerDataImport
            Mock Add-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should skip import when table exists" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Skip"

            # Assert
            $result.Skipped | Should -Be $true
            $result.RowsImported | Should -Be 0
            Should -Invoke Import-DataFile -Times 0 -ModuleName SqlServerDataImport
        }
    }

    Context "TableExistsAction - Truncate" {
        BeforeEach {
            $testFile = Join-Path $TestDrive "TEST_Employee.dat"
            "EMP001|John|Doe" | Set-Content $testFile
            $fileInfo = Get-Item $testFile

            $tableSpecs = @(
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            )

            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport
            Mock Clear-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 50 } -ModuleName SqlServerDataImport
            Mock Add-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should truncate table and import when table exists" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Truncate"

            # Assert
            Should -Invoke Clear-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
            $result.Skipped | Should -Be $false
            $result.RowsImported | Should -Be 50
        }
    }

    Context "TableExistsAction - Recreate" {
        BeforeEach {
            $testFile = Join-Path $TestDrive "TEST_Employee.dat"
            "EMP001|John|Doe" | Set-Content $testFile
            $fileInfo = Get-Item $testFile

            $tableSpecs = @(
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            )

            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport
            Mock Remove-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 75 } -ModuleName SqlServerDataImport
            Mock Add-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should drop and recreate table when table exists" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Recreate"

            # Assert
            Should -Invoke Remove-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke New-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
            $result.Skipped | Should -Be $false
            $result.RowsImported | Should -Be 75
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $testFile = Join-Path $TestDrive "TEST_Unknown.dat"
            "DATA001|Value" | Set-Content $testFile
            $fileInfo = Get-Item $testFile

            $tableSpecs = @(
                [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            )

            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 0 } -ModuleName SqlServerDataImport
            Mock Add-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should skip when no field specifications found for table" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $result = Invoke-TableImportProcess -DataFile $fileInfo `
                                                -ConnectionString $connString `
                                                -SchemaName "dbo" `
                                                -Prefix "TEST_" `
                                                -TableSpecs $tableSpecs `
                                                -TableExistsAction "Skip"

            # Assert
            $result.Skipped | Should -Be $true
            $result.RowsImported | Should -Be 0
            Should -Invoke Import-DataFile -Times 0 -ModuleName SqlServerDataImport
        }
    }
    }
}
