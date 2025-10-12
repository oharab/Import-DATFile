# Clear-DatabaseTable.Tests.ps1
# Unit tests for Clear-DatabaseTable function

BeforeAll {
    # Import the main module first (loads dependencies)
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Dot-source the function and its dependencies
    . (Join-Path $moduleRoot "Private\Database\Clear-DatabaseTable.ps1")
    . (Join-Path $moduleRoot "Private\Database\Get-DatabaseErrorGuidance.ps1")
}

Describe "Clear-DatabaseTable" {

    BeforeEach {
        # Test data
        $script:TestConnectionString = "Server=testserver;Database=testdb;Integrated Security=True;"
        $script:TestSchemaName = "dbo"
        $script:TestTableName = "Employee"
    }

    Context "ShouldProcess Support" {
        It "Should support -WhatIf parameter" {
            # Arrange
            $command = Get-Command Clear-DatabaseTable

            # Assert
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
            $command.Parameters['WhatIf'].SwitchParameter | Should -Be $true
        }

        It "Should support -Confirm parameter" {
            # Arrange
            $command = Get-Command Clear-DatabaseTable

            # Assert
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Confirm'].SwitchParameter | Should -Be $true
        }

        It "Should not execute Invoke-Sqlcmd when -WhatIf is specified" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Should not be called in WhatIf mode" }

            # Act
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
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
            $output = Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                          -SchemaName $TestSchemaName `
                                          -TableName $TestTableName `
                                          -WhatIf 6>&1

            # Assert
            $output | Should -Not -BeNullOrEmpty
            # ShouldProcess should show "Truncate table (DELETES ALL DATA)" in the operation description
        }
    }

    Context "Successful Table Truncation" {
        It "Should truncate table successfully with valid inputs" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName $TestSchemaName `
                                  -TableName $TestTableName } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly
        }

        It "Should call Invoke-Sqlcmd with correct ConnectionString" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $ConnectionString -eq $TestConnectionString
            }
        }
    }

    Context "SQL Generation" {
        It "Should generate TRUNCATE TABLE statement" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName $TestSchemaName `
                                -TableName $TestTableName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -eq "TRUNCATE TABLE [$TestSchemaName].[$TestTableName]"
            }
        }

        It "Should bracket schema and table names" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                -SchemaName "test_schema" `
                                -TableName "test_table"

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "\[test_schema\]\.\[test_table\]"
            }
        }
    }

    Context "Error Handling" {
        It "Should throw meaningful error when table does not exist" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Cannot truncate table 'Employee' because it does not exist" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName $TestSchemaName `
                                  -TableName $TestTableName } | Should -Throw "*Failed to truncate table*"
        }

        It "Should throw meaningful error when table has foreign key references" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Cannot truncate table because it is referenced by a FOREIGN KEY constraint" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName $TestSchemaName `
                                  -TableName $TestTableName } | Should -Throw "*Failed to truncate table*"
        }

        It "Should call Get-DatabaseErrorGuidance on SQL failure" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance { return "Guidance" }

            # Act
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
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
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
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
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName "invalid-schema!" `
                                  -TableName $TestTableName } | Should -Throw
        }

        It "Should accept valid SchemaName with underscores and numbers" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName "valid_schema_123" `
                                  -TableName $TestTableName } | Should -Not -Throw
        }

        It "Should require ConnectionString parameter" {
            # Act & Assert
            { Clear-DatabaseTable -SchemaName $TestSchemaName `
                                  -TableName $TestTableName } | Should -Throw
        }

        It "Should require SchemaName parameter" {
            # Act & Assert
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -TableName $TestTableName } | Should -Throw
        }

        It "Should require TableName parameter" {
            # Act & Assert
            { Clear-DatabaseTable -ConnectionString $TestConnectionString `
                                  -SchemaName $TestSchemaName } | Should -Throw
        }
    }

    Context "Destructive Operation Safety" {
        It "Should be a destructive operation (requires explicit -Confirm:$false in scripts)" {
            # This test documents that Clear-DatabaseTable is destructive and requires
            # explicit confirmation or -Confirm:$false in automated scripts

            # Arrange
            $command = Get-Command Clear-DatabaseTable

            # Assert - Function has ShouldProcess, meaning it requires confirmation
            $command.ScriptBlock.Attributes | Where-Object { $_.TypeId.Name -eq 'CmdletBindingAttribute' } |
                ForEach-Object { $_.SupportsShouldProcess } | Should -Be $true
        }
    }
}
