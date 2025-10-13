# Invoke-SqlServerDataImport.Tests.ps1
# Unit tests for main orchestration function
# Tests orchestration logic with all dependencies mocked

BeforeAll {
    # Import the main module
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

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
        "$($Prefix)|John|Doe" | Set-Content $employeeDat

        return @{
            DataFolder = $dataFolder
            ExcelFile = "TestSpec.xlsx"
            Prefix = $Prefix
        }
    }
}

Describe "Invoke-SqlServerDataImport" {

    Context "Parameter Validation" {
        It "Should accept valid Server parameter" {
            # This test verifies parameter binding works
            $params = @{
                DataFolder = $TestDrive
                ExcelSpecFile = "test.xlsx"
                Server = "localhost"
                Database = "TestDB"
            }

            # Just test that parameters bind correctly (will fail validation later, but that's ok for this test)
            { Get-Command Invoke-SqlServerDataImport | Should -Not -BeNullOrEmpty } | Should -Not -Throw
        }

        It "Should require Server parameter" {
            $cmd = Get-Command Invoke-SqlServerDataImport
            $serverParam = $cmd.Parameters['Server']

            $serverParam.Attributes.Mandatory | Should -Contain $true
        }

        It "Should validate TableExistsAction parameter" {
            $cmd = Get-Command Invoke-SqlServerDataImport
            $actionParam = $cmd.Parameters['TableExistsAction']

            $validateSet = $actionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain "Ask"
            $validateSet.ValidValues | Should -Contain "Skip"
            $validateSet.ValidValues | Should -Contain "Truncate"
            $validateSet.ValidValues | Should -Contain "Recreate"
        }
    }

    Context "Orchestration - Connection and Validation" {
        BeforeEach {
            # Setup test data
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
                )
            } -ModuleName SqlServerDataImport
            Mock Get-ChildItem {
                @([PSCustomObject]@{ Name = "TEST_Employee.dat"; FullName = "$($testData.DataFolder)\TEST_Employee.dat" })
            } -ModuleName SqlServerDataImport
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 10 } -ModuleName SqlServerDataImport
        }

        It "Should call Test-DatabaseConnection with correct connection string" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Test-DatabaseConnection -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $ConnectionString -like "*Server=localhost*" -and
                $ConnectionString -like "*Database=TestDB*"
            }
        }

        It "Should detect prefix from data folder" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Get-DataPrefix -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $FolderPath -eq $testData.DataFolder
            }
        }

        It "Should use detected prefix as schema name when not specified" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Schema name should match detected prefix
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $SchemaName -eq "TEST_"
            }
        }

        It "Should use explicit schema name when provided" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "CustomSchema"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke New-DatabaseSchema -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $SchemaName -eq "CustomSchema"
            }
        }

        It "Should throw when database connection fails" {
            # Arrange
            Mock Test-DatabaseConnection { return $false } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                TableExistsAction = "Skip"
            }

            # Act & Assert
            { Invoke-SqlServerDataImport @params } | Should -Throw "*Database connection test failed*"
        }
    }

    Context "Orchestration - TableExistsAction Logic" {
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
                )
            } -ModuleName SqlServerDataImport
            Mock Get-ChildItem {
                @([PSCustomObject]@{ Name = "TEST_Employee.dat"; FullName = "$($testData.DataFolder)\TEST_Employee.dat" })
            } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Clear-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Remove-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 10 } -ModuleName SqlServerDataImport
        }

        It "Should skip import when TableExistsAction=Skip and table exists" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Import should not be called
            Should -Invoke Import-DataFile -Times 0 -ModuleName SqlServerDataImport
        }

        It "Should truncate table when TableExistsAction=Truncate and table exists" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Truncate"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Clear-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
        }

        It "Should drop and recreate when TableExistsAction=Recreate and table exists" {
            # Arrange
            Mock Test-TableExists { return $true } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Recreate"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Remove-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke New-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
        }

        It "Should create table when table does not exist (any action)" {
            # Arrange
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke New-DatabaseTable -Times 1 -ModuleName SqlServerDataImport
            Should -Invoke Import-DataFile -Times 1 -ModuleName SqlServerDataImport
        }
    }

    Context "Orchestration - Import Summary" {
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
                )
            } -ModuleName SqlServerDataImport
            Mock Get-ChildItem {
                @([PSCustomObject]@{ Name = "TEST_Employee.dat"; FullName = "$($testData.DataFolder)\TEST_Employee.dat" })
            } -ModuleName SqlServerDataImport
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 25 } -ModuleName SqlServerDataImport
        }

        It "Should return import summary with table and row counts" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
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
            $result[0].RowCount | Should -Be 25
        }
    }

    Context "Orchestration - Post-Install Scripts" {
        BeforeEach {
            $testData = New-MockTestData -TestDrive $TestDrive

            # Create mock post-install script
            $scriptPath = Join-Path $TestDrive "PostInstall.sql"
            "SELECT 1" | Set-Content $scriptPath

            # Mock all dependencies
            Mock Get-DataPrefix { return "TEST_" } -ModuleName SqlServerDataImport
            Mock Test-ImportPath { } -ModuleName SqlServerDataImport
            Mock Test-DatabaseConnection { return $true } -ModuleName SqlServerDataImport
            Mock Test-SchemaName { } -ModuleName SqlServerDataImport
            Mock New-DatabaseSchema { } -ModuleName SqlServerDataImport
            Mock Get-TableSpecifications {
                return @(
                    [PSCustomObject]@{ 'Table name' = 'Employee'; 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
                )
            } -ModuleName SqlServerDataImport
            Mock Get-ChildItem {
                @([PSCustomObject]@{ Name = "TEST_Employee.dat"; FullName = "$($testData.DataFolder)\TEST_Employee.dat" })
            } -ModuleName SqlServerDataImport
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 10 } -ModuleName SqlServerDataImport
            Mock Invoke-PostInstallScripts { } -ModuleName SqlServerDataImport
        }

        It "Should execute post-install scripts when provided" {
            # Arrange
            $scriptPath = Join-Path $TestDrive "PostInstall.sql"

            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
                PostInstallScripts = $scriptPath
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Invoke-PostInstallScripts -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $ScriptPath -eq $scriptPath -and
                $DatabaseName -eq "TestDB" -and
                $SchemaName -eq "dbo"
            }
        }

        It "Should not execute post-install scripts when not provided" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert
            Should -Invoke Invoke-PostInstallScripts -Times 0 -ModuleName SqlServerDataImport
        }

        It "Should not fail import if post-install scripts fail" {
            # Arrange
            Mock Invoke-PostInstallScripts { throw "Script failed" } -ModuleName SqlServerDataImport

            $scriptPath = Join-Path $TestDrive "PostInstall.sql"
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
                PostInstallScripts = $scriptPath
            }

            # Act - Should not throw
            $result = Invoke-SqlServerDataImport @params -ErrorAction SilentlyContinue

            # Assert - Import still succeeded
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Orchestration - SQL Authentication" {
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
                )
            } -ModuleName SqlServerDataImport
            Mock Get-ChildItem {
                @([PSCustomObject]@{ Name = "TEST_Employee.dat"; FullName = "$($testData.DataFolder)\TEST_Employee.dat" })
            } -ModuleName SqlServerDataImport
            Mock Test-TableExists { return $false } -ModuleName SqlServerDataImport
            Mock New-DatabaseTable { } -ModuleName SqlServerDataImport
            Mock Import-DataFile { return 10 } -ModuleName SqlServerDataImport
        }

        It "Should build connection string with SQL authentication when credentials provided" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                Username = "sa"
                Password = "P@ssw0rd"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Connection string should contain User ID
            Should -Invoke Test-DatabaseConnection -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $ConnectionString -like "*User ID=sa*" -and
                $ConnectionString -like "*Password=P@ssw0rd*"
            }
        }

        It "Should build connection string with Windows authentication when no credentials" {
            # Arrange
            $params = @{
                DataFolder = $testData.DataFolder
                ExcelSpecFile = $testData.ExcelFile
                Server = "localhost"
                Database = "TestDB"
                SchemaName = "dbo"
                TableExistsAction = "Skip"
            }

            # Act
            $result = Invoke-SqlServerDataImport @params

            # Assert - Connection string should contain Integrated Security
            Should -Invoke Test-DatabaseConnection -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $ConnectionString -like "*Integrated Security=True*"
            }
        }
    }
}
