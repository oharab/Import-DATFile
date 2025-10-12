# Remove-DatabaseTable.Tests.ps1
# Unit tests for Remove-DatabaseTable function

BeforeAll {
    # Import the main module first (loads dependencies)
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Dot-source the function and its dependencies
    . (Join-Path $moduleRoot "Private\Database\Remove-DatabaseTable.ps1")
    . (Join-Path $moduleRoot "Private\Database\Get-DatabaseErrorGuidance.ps1")
}

Describe "Remove-DatabaseTable" {

    BeforeEach {
        # Test data
        $script:TestConnectionString = "Server=testserver;Database=testdb;Integrated Security=True;"
        $script:TestSchemaName = "dbo"
        $script:TestTableName = "Employee"
    }

    Context "ShouldProcess Support" {
        It "Should support -WhatIf parameter" {
            # Arrange
            $command = Get-Command Remove-DatabaseTable

            # Assert
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
            $command.Parameters['WhatIf'].SwitchParameter | Should -Be $true
        }

        It "Should support -Confirm parameter" {
            # Arrange
            $command = Get-Command Remove-DatabaseTable

            # Assert
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Confirm'].SwitchParameter | Should -Be $true
        }

        It "Should not execute Invoke-Sqlcmd when -WhatIf is specified" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Should not be called in WhatIf mode" }

            # Act
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName `
                                   -WhatIf } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 0 -Exactly
        }

        It "Should display destructive warning in WhatIf mode" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            $output = Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                            -SchemaName $TestSchemaName `
                                            -TableName $TestTableName `
                                            -WhatIf 6>&1

            # Assert
            $output | Should -Not -BeNullOrEmpty
            # ShouldProcess should show "Drop table (DELETES ALL DATA)" in the operation description
        }
    }

    Context "Successful Table Removal" {
        It "Should drop table successfully with valid inputs" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly
        }

        It "Should call Invoke-Sqlcmd with correct ConnectionString" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName `
                                 -TableName $TestTableName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $ConnectionString -eq $TestConnectionString
            }
        }
    }

    Context "SQL Generation" {
        It "Should generate DROP TABLE statement" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName `
                                 -TableName $TestTableName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -eq "DROP TABLE [$TestSchemaName].[$TestTableName]"
            }
        }

        It "Should bracket schema and table names" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                 -SchemaName "test_schema" `
                                 -TableName "test_table" `

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[test_schema\]\.\[test_table\]"
            }
        }
    }

    Context "Error Handling" {
        It "Should throw meaningful error when table does not exist" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Cannot drop the table 'Employee', because it does not exist" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName } | Should -Throw "*Failed to drop table*"
        }

        It "Should throw meaningful error when table is in use" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Cannot drop table because it is being used" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName } | Should -Throw "*Failed to drop table*"
        }

        It "Should call Get-DatabaseErrorGuidance on SQL failure" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance { return "Guidance" }

            # Act
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName } | Should -Throw

            # Assert
            Assert-MockCalled Get-DatabaseErrorGuidance -Times 1 -Exactly
        }

        It "Should include table name in error context" {
            # Arrange
            $script:capturedContext = $null
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance {
                param($Operation, $ErrorMessage, $Context)
                $script:capturedContext = $Context
                return "Guidance"
            }

            # Act
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName $TestSchemaName `
                                   -TableName $TestTableName } | Should -Throw

            # Assert
            $script:capturedContext.SchemaName | Should -Be $TestSchemaName
            $script:capturedContext.TableName | Should -Be $TestTableName
        }
    }

    Context "Parameter Validation" {
        It "Should validate SchemaName pattern (alphanumeric and underscore only)" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName "invalid-schema!" `
                                   -TableName $TestTableName } | Should -Throw
        }

        It "Should accept valid SchemaName with underscores and numbers" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { Remove-DatabaseTable -ConnectionString $TestConnectionString `
                                   -SchemaName "valid_schema_123" `
                                   -TableName $TestTableName } | Should -Not -Throw
        }

        It "Should require ConnectionString parameter" {
            # Arrange
            $command = Get-Command Remove-DatabaseTable

            # Assert
            $command.Parameters['ConnectionString'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should require SchemaName parameter" {
            # Arrange
            $command = Get-Command Remove-DatabaseTable

            # Assert
            $command.Parameters['SchemaName'].Attributes.Mandatory | Should -Contain $true
        }

        It "Should require TableName parameter" {
            # Arrange
            $command = Get-Command Remove-DatabaseTable

            # Assert
            $command.Parameters['TableName'].Attributes.Mandatory | Should -Contain $true
        }
    }
}
