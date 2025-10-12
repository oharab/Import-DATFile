# Initialize-ImportContext.Tests.ps1
# Unit tests for Initialize-ImportContext function

# Import module at script scope (required for InModuleScope)
$moduleRoot = Join-Path $PSScriptRoot "..\..\..\.."
$modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
Import-Module $modulePath -Force

InModuleScope SqlServerDataImport {
    BeforeAll {
        # Test data setup helper
        function New-MockTestData {
            param([string]$TestDrive, [string]$Prefix = "TEST_")

            $dataFolder = Join-Path $TestDrive "TestData"
            New-Item -ItemType Directory -Path $dataFolder -Force | Out-Null

            # Create Excel file (mock - just needs to exist)
            $excelPath = Join-Path $dataFolder "TestSpec.xlsx"
            "Mock Excel" | Set-Content $excelPath

            # Create Employee.dat file (for prefix detection)
            $employeeDat = Join-Path $dataFolder "$($Prefix)Employee.dat"
            "EMP001|John|Doe" | Set-Content $employeeDat

            # Create another DAT file
            $deptDat = Join-Path $dataFolder "$($Prefix)Department.dat"
            "DEPT001|IT" | Set-Content $deptDat

            return @{
                DataFolder = $dataFolder
                ExcelFile = "TestSpec.xlsx"
                Prefix = $Prefix
            }
        }
    }

    Describe "Initialize-ImportContext" {

        Context "Successful Initialization" {
        BeforeEach {
            $testData = New-MockTestData -TestDrive $TestDrive

            # Mock all dependencies
            Mock Get-DataPrefix { return "TEST_" } -ModuleName SqlServerDataImport
            Mock Test-ImportPath { } -ModuleName SqlServerDataImport
            Mock Test-DatabaseConnection { return $true } -ModuleName SqlServerDataImport
            Mock Test-SchemaName { } -ModuleName SqlServerDataImport
            Mock New-DatabaseSchema { } -ModuleName SqlServerDataImport
            Mock Get-TableSpecifications {
                return @(
                    [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
                    [PSCustomObject]@{ 'Table name' = 'Department'; 'Column name' = 'Name'; 'Data type' = 'VARCHAR'; Precision = 100 }
                )
            } -ModuleName SqlServerDataImport
        }

        It "Should return context object with required keys" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $context = Initialize-ImportContext -DataFolder $testData.DataFolder `
                                                -ExcelSpecFile $testData.ExcelFile `
                                                -ConnectionString $connString

            # Assert
            $context | Should -Not -BeNullOrEmpty
            $context.ConnectionString | Should -Be $connString
            $context.SchemaName | Should -Be "TEST_"
            $context.Prefix | Should -Be "TEST_"
            $context.TableSpecs | Should -Not -BeNullOrEmpty
            $context.DataFiles | Should -Not -BeNullOrEmpty
        }

        It "Should use detected prefix as schema name when not specified" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $context = Initialize-ImportContext -DataFolder $testData.DataFolder `
                                                -ExcelSpecFile $testData.ExcelFile `
                                                -ConnectionString $connString

            # Assert
            $context.SchemaName | Should -Be "TEST_"
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $SchemaName -eq "TEST_"
            }
        }

        It "Should use explicit schema name when provided" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $context = Initialize-ImportContext -DataFolder $testData.DataFolder `
                                                -ExcelSpecFile $testData.ExcelFile `
                                                -ConnectionString $connString `
                                                -SchemaName "CustomSchema"

            # Assert
            $context.SchemaName | Should -Be "CustomSchema"
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $SchemaName -eq "CustomSchema"
            }
        }

        It "Should discover DAT files with matching prefix" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $context = Initialize-ImportContext -DataFolder $testData.DataFolder `
                                                -ExcelSpecFile $testData.ExcelFile `
                                                -ConnectionString $connString

            # Assert
            $context.DataFiles | Should -Not -BeNullOrEmpty
            $context.DataFiles.Count | Should -Be 2
            $context.DataFiles[0].Name | Should -Match "^TEST_"
            $context.DataFiles[1].Name | Should -Match "^TEST_"
        }

        It "Should call all validation functions" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            $context = Initialize-ImportContext -DataFolder $testData.DataFolder `
                                                -ExcelSpecFile $testData.ExcelFile `
                                                -ConnectionString $connString

            # Assert
            Should -Invoke Test-ImportPath -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Get-DataPrefix -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Test-DatabaseConnection -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Test-SchemaName -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Get-TableSpecifications -Times 1 -ModuleName SqlServerDataImport
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $testData = New-MockTestData -TestDrive $TestDrive

            # Mock dependencies with default success
            Mock Get-DataPrefix { return "TEST_" } -ModuleName SqlServerDataImport
            Mock Test-ImportPath { } -ModuleName SqlServerDataImport
            Mock Test-SchemaName { } -ModuleName SqlServerDataImport
            Mock New-DatabaseSchema { } -ModuleName SqlServerDataImport
            Mock Get-TableSpecifications {
                return @(
                    [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
                )
            } -ModuleName SqlServerDataImport
        }

        It "Should throw when database connection fails" {
            # Arrange
            Mock Test-DatabaseConnection { return $false } -ModuleName SqlServerDataImport
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act & Assert
            { Initialize-ImportContext -DataFolder $testData.DataFolder `
                                      -ExcelSpecFile $testData.ExcelFile `
                                      -ConnectionString $connString } |
                Should -Throw "*Database connection test failed*"
        }

        It "Should throw when no DAT files found" {
            # Arrange
            Mock Test-DatabaseConnection { return $true } -ModuleName SqlServerDataImport

            # Create folder with no DAT files
            $emptyFolder = Join-Path $TestDrive "EmptyData"
            New-Item -ItemType Directory -Path $emptyFolder -Force | Out-Null
            $excelPath = Join-Path $emptyFolder "TestSpec.xlsx"
            "Mock" | Set-Content $excelPath

            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act & Assert
            { Initialize-ImportContext -DataFolder $emptyFolder `
                                      -ExcelSpecFile "TestSpec.xlsx" `
                                      -ConnectionString $connString } |
                Should -Throw "*No .dat files found*"
        }
    }
    }
}
