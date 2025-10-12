# New-DatabaseSchema.Tests.ps1
# Unit tests for New-DatabaseSchema function

BeforeAll {
    # Import the main module first (loads dependencies)
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Dot-source the function and its dependencies
    . (Join-Path $moduleRoot "Private\Database\New-DatabaseSchema.ps1")
    . (Join-Path $moduleRoot "Private\Database\Get-DatabaseErrorGuidance.ps1")
}

Describe "New-DatabaseSchema" {

    BeforeEach {
        # Test data
        $script:TestConnectionString = "Server=testserver;Database=testdb;Integrated Security=True;"
        $script:TestSchemaName = "MySchema"
    }

    Context "ShouldProcess Support" {
        It "Should support -WhatIf parameter" {
            # Arrange
            $command = Get-Command New-DatabaseSchema

            # Assert
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
            $command.Parameters['WhatIf'].SwitchParameter | Should -Be $true
        }

        It "Should support -Confirm parameter" {
            # Arrange
            $command = Get-Command New-DatabaseSchema

            # Assert
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Confirm'].SwitchParameter | Should -Be $true
        }

        It "Should not execute Invoke-Sqlcmd when -WhatIf is specified" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "Should not be called in WhatIf mode" }

            # Act
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName `
                                 -WhatIf } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 0 -Exactly
        }

        It "Should display informational message in WhatIf mode" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            $output = New-DatabaseSchema -ConnectionString $TestConnectionString `
                                         -SchemaName $TestSchemaName `
                                         -WhatIf 6>&1

            # Assert
            $output | Should -Not -BeNullOrEmpty
        }
    }

    Context "Successful Schema Creation" {
        It "Should create or verify schema successfully with valid inputs" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName } | Should -Not -Throw

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly
        }

        It "Should call Invoke-Sqlcmd with correct ConnectionString" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseSchema -ConnectionString $TestConnectionString `
                               -SchemaName $TestSchemaName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $ConnectionString -eq $TestConnectionString
            }
        }
    }

    Context "SQL Generation" {
        It "Should generate idempotent schema creation query" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseSchema -ConnectionString $TestConnectionString `
                               -SchemaName $TestSchemaName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "IF NOT EXISTS" -and
                $Query -match "CREATE SCHEMA" -and
                $Query -match $script:TestSchemaName
            }
        }

        It "Should use parameterized query to prevent SQL injection" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseSchema -ConnectionString $TestConnectionString `
                               -SchemaName $TestSchemaName

            # Assert
            # Query should use variable instead of direct string concatenation for schema name check
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "DECLARE @SchemaName" -and
                $Query -match "@SchemaName.*'$script:TestSchemaName'"
            }
        }

        It "Should bracket schema name in CREATE SCHEMA statement" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseSchema -ConnectionString $TestConnectionString `
                               -SchemaName $TestSchemaName

            # Assert
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "CREATE SCHEMA \["
            }
        }
    }

    Context "Error Handling" {
        It "Should throw meaningful error on SQL failure" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "User does not have permission to create schema" }
            Mock Get-DatabaseErrorGuidance { return "Detailed guidance message" }

            # Act & Assert
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName } | Should -Throw "*Failed to create schema*"
        }

        It "Should call Get-DatabaseErrorGuidance on SQL failure" {
            # Arrange
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance { return "Guidance" }

            # Act
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName } | Should -Throw

            # Assert
            Assert-MockCalled Get-DatabaseErrorGuidance -Times 1 -Exactly
        }

        It "Should include schema name in error context" {
            # Arrange
            $script:capturedContext = $null
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance {
                param($Operation, $ErrorMessage, $Context)
                $script:capturedContext = $Context
                return "Guidance"
            }

            # Act
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName $TestSchemaName } | Should -Throw

            # Assert
            $script:capturedContext.SchemaName | Should -Be $TestSchemaName
        }

        It "Should extract database name from connection string for error context" {
            # Arrange
            $script:capturedContext = $null
            $connString = "Server=testserver;Database=TestDatabase;Integrated Security=True;"
            Mock Invoke-Sqlcmd { throw "SQL error" }
            Mock Get-DatabaseErrorGuidance {
                param($Operation, $ErrorMessage, $Context)
                $script:capturedContext = $Context
                return "Guidance"
            }

            # Act
            { New-DatabaseSchema -ConnectionString $connString `
                                 -SchemaName $TestSchemaName } | Should -Throw

            # Assert
            $script:capturedContext.Database | Should -Be "TestDatabase"
        }
    }

    Context "Parameter Validation" {
        It "Should validate SchemaName pattern (alphanumeric and underscore only)" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName "invalid-schema!" } | Should -Throw
        }

        It "Should accept valid SchemaName with underscores and numbers" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName "valid_schema_123" } | Should -Not -Throw
        }

        It "Should reject SchemaName with special characters" {
            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act & Assert
            { New-DatabaseSchema -ConnectionString $TestConnectionString `
                                 -SchemaName "schema-with-dashes" } | Should -Throw
        }

        It "Should require ConnectionString parameter" {
            # Act & Assert
            { New-DatabaseSchema -SchemaName $TestSchemaName } | Should -Throw
        }

        It "Should require SchemaName parameter" {
            # Act & Assert
            { New-DatabaseSchema -ConnectionString $TestConnectionString } | Should -Throw
        }
    }

    Context "Idempotency" {
        It "Should be idempotent (safe to run multiple times)" {
            # This test documents that New-DatabaseSchema checks for existence
            # before creating, making it safe to run multiple times

            # Arrange
            Mock Invoke-Sqlcmd { }

            # Act
            New-DatabaseSchema -ConnectionString $TestConnectionString `
                               -SchemaName $TestSchemaName

            # Assert - Query should check existence before creating
            Assert-MockCalled Invoke-Sqlcmd -Times 1 -Exactly -ParameterFilter {
                $Query -match "IF NOT EXISTS"
            }
        }
    }
}
