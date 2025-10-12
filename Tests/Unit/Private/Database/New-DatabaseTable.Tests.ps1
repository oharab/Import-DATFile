# New-DatabaseTable.Tests.ps1
# Unit tests for New-DatabaseTable function

BeforeAll {
    # Import the main module first (loads dependencies)
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Dot-source the function and its dependencies
    . (Join-Path $moduleRoot "Private\Database\New-DatabaseTable.ps1")
    . (Join-Path $moduleRoot "Private\Database\Get-DatabaseErrorGuidance.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\Get-SqlDataTypeMapping.ps1")
}

Describe "New-DatabaseTable" {

    BeforeEach {
        # Test data
        $script:TestConnectionString = "Server=testserver;Database=testdb;Integrated Security=True;"
        $script:TestSchemaName = "dbo"
        $script:TestTableName = "Employee"
        $script:TestFields = @(
            [PSCustomObject]@{ 'Column name' = 'FirstName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            [PSCustomObject]@{ 'Column name' = 'LastName'; 'Data type' = 'VARCHAR'; Precision = 50 }
            [PSCustomObject]@{ 'Column name' = 'Age'; 'Data type' = 'INT'; Precision = $null }
        )
    }

    Context "ShouldProcess Support" {
        It "Should support -WhatIf parameter" {
            # Arrange
            $command = Get-Command New-DatabaseTable

            # Assert
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
            $command.Parameters['WhatIf'].SwitchParameter | Should -Be $true
        }

        It "Should support -Confirm parameter" {
            # Arrange
            $command = Get-Command New-DatabaseTable

            # Assert
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Confirm'].SwitchParameter | Should -Be $true
        }

        It "Should not execute Invoke-Sqlcmd when -WhatIf is specified" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Should not be called in WhatIf mode" }

            # Act
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName `
                                -Fields $TestFields `
                                -WhatIf } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 0 -Exactly
        }

        It "Should display CREATE TABLE statement when -WhatIf is specified" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            $output = New-DatabaseTable -ConnectionString $TestConnectionString `
                                         -SchemaName $TestSchemaName `
                                         -TableName $TestTableName `
                                         -Fields $TestFields `
                                         -WhatIf 6>&1

            # Assert
            $output | Should -Not -BeNullOrEmpty
        }
    }

    Context "Successful Table Creation" {
        It "Should create table successfully with valid inputs" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName `
                                -Fields $TestFields } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly
        }

        It "Should call Invoke-Sqlcmd with correct ConnectionString" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName $TestSchemaName `
                              -TableName $TestTableName `
                              -Fields $TestFields

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $ConnectionString -eq $TestConnectionString
            }
        }
    }

    Context "SQL Generation" {
        It "Should generate CREATE TABLE statement with ImportID as first column" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName $TestSchemaName `
                              -TableName $TestTableName `
                              -Fields $TestFields

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "CREATE TABLE \[$TestSchemaName\]\.\[$TestTableName\]" -and
                $Query -match "\[ImportID\] VARCHAR\(255\)"
            }
        }

        It "Should include all specified fields in CREATE TABLE statement" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName $TestSchemaName `
                              -TableName $TestTableName `
                              -Fields $TestFields

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[FirstName\] VARCHAR\(50\)" -and
                $Query -match "\[LastName\] VARCHAR\(50\)" -and
                $Query -match "\[Age\] INT"
            }
        }

        It "Should bracket schema and table names to handle special characters" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName "test_schema" `
                              -TableName "test_table" `
                              -Fields $TestFields

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[test_schema\]\.\[test_table\]"
            }
        }
    }

    Context "Error Handling" {
        It "Should throw meaningful error when SQL execution fails" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "SQL Server error: Table already exists" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName `
                                -Fields $TestFields } | Should -Throw "*Failed to create table*"
        }

        It "Should call Get-DatabaseErrorGuidance on SQL failure" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance { return "Guidance" }

            # Act
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName `
                                -Fields $TestFields } | Should -Throw

            # Assert
            Assert-MockCalled Get-DatabaseErrorGuidance -Times 1 -Exactly
        }
    }

    Context "Parameter Validation" {
        It "Should validate SchemaName pattern (alphanumeric and underscore only)" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName "invalid-schema!" `
                                -TableName $TestTableName `
                                -Fields $TestFields } | Should -Throw
        }

        It "Should accept valid SchemaName with underscores" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { New-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName "valid_schema_123" `
                                -TableName $TestTableName `
                                -Fields $TestFields } | Should -Not -Throw
        }

        It "Should require Fields parameter" {
            # Arrange
            $command = Get-Command New-DatabaseTable

            # Assert
            $command.Parameters['Fields'].Attributes.Mandatory | Should -Contain $true
        }
    }

    Context "Edge Cases" {
        It "Should handle single field specification" {
            # Arrange
            $singleField = @(
                [PSCustomObject]@{ 'Column name' = 'Name'; 'Data type' = 'VARCHAR'; Precision = 100 }
            )
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName $TestSchemaName `
                              -TableName $TestTableName `
                              -Fields $singleField

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[ImportID\] VARCHAR\(255\)" -and
                $Query -match "\[Name\] VARCHAR\(100\)"
            }
        }

        It "Should handle fields with no precision (e.g., INT, DATETIME)" {
            # Arrange
            $fieldsNoPrecision = @(
                [PSCustomObject]@{ 'Column name' = 'ID'; 'Data type' = 'INT'; Precision = $null }
                [PSCustomObject]@{ 'Column name' = 'CreatedDate'; 'Data type' = 'DATETIME'; Precision = $null }
            )
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseTable -ConnectionString $TestConnectionString `
                              -SchemaName $TestSchemaName `
                              -TableName $TestTableName `
                              -Fields $fieldsNoPrecision

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[ID\] INT" -and
                $Query -match "\[CreatedDate\] DATETIME"
            }
        }
    }
}
