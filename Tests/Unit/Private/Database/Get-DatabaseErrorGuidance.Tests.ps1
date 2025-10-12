# Get-DatabaseErrorGuidance.Tests.ps1
# Unit tests for Get-DatabaseErrorGuidance function

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"

    # Dot-source the function
    . (Join-Path $moduleRoot "Private\Database\Get-DatabaseErrorGuidance.ps1")
}

Describe "Get-DatabaseErrorGuidance" {

    Context "Connection Operation Guidance" {
        It "Should provide connection guidance with SQL authentication" {
            # Arrange
            $context = @{
                Server = 'localhost\SQLEXPRESS'
                Database = 'TestDB'
                Username = 'sa'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Login failed" `
                                                   -Context $context

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "localhost\\SQLEXPRESS"
            $guidance | Should -Match "TestDB"
            $guidance | Should -Match "SQL Authentication"
            $guidance | Should -Match "Login failed"
        }

        It "Should provide connection guidance with Windows authentication" {
            # Arrange
            $context = @{
                Server = 'localhost'
                Database = 'MyDB'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Network error" `
                                                   -Context $context

            # Assert
            $guidance | Should -Match "Windows Authentication"
            $guidance | Should -Match "Windows account"
            $guidance | Should -Not -Match "SQL Auth"
        }

        It "Should include troubleshooting checklist for connection" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Connection timeout" `
                                                   -Context @{Server='srv'; Database='db'}

            # Assert
            $guidance | Should -Match "Server name/instance"
            $guidance | Should -Match "SQL Server service"
            $guidance | Should -Match "Firewall"
            $guidance | Should -Match "port 1433"
            $guidance | Should -Match "ping"
        }
    }

    Context "Schema Operation Guidance" {
        It "Should provide schema creation guidance" {
            # Arrange
            $context = @{
                SchemaName = 'MySchema'
                Database = 'TestDB'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Schema" `
                                                   -ErrorMessage "Permission denied" `
                                                   -Context $context

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "MySchema"
            $guidance | Should -Match "TestDB"
            $guidance | Should -Match "CREATE SCHEMA"
            $guidance | Should -Match "Permission denied"
        }

        It "Should include permission grant statements for schema" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Schema" `
                                                   -ErrorMessage "Access denied" `
                                                   -Context @{SchemaName='test'; Database='db'}

            # Assert
            $guidance | Should -Match "GRANT CREATE SCHEMA"
            $guidance | Should -Match "db_ddladmin"
        }
    }

    Context "TableCreate Operation Guidance" {
        It "Should provide table creation guidance" {
            # Arrange
            $context = @{
                SchemaName = 'dbo'
                TableName = 'Employee'
                SQL = 'CREATE TABLE [dbo].[Employee] ([ID] INT)'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableCreate" `
                                                   -ErrorMessage "Invalid syntax" `
                                                   -Context $context

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "\[dbo\]\.\[Employee\]"
            $guidance | Should -Match "CREATE TABLE"
            $guidance | Should -Match "Invalid syntax"
        }

        It "Should include SQL statement when provided" {
            # Arrange
            $sql = "CREATE TABLE [test].[MyTable] ([Col1] VARCHAR(50))"
            $context = @{
                SchemaName = 'test'
                TableName = 'MyTable'
                SQL = $sql
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableCreate" `
                                                   -ErrorMessage "Error" `
                                                   -Context $context

            # Assert
            $guidance | Should -Match "CREATE TABLE statement that failed:"
            $guidance | Should -Match "\[test\]\.\[MyTable\]"
            $guidance | Should -Match "VARCHAR\(50\)"
        }

        It "Should include troubleshooting checklist for table creation" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableCreate" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{SchemaName='s'; TableName='t'}

            # Assert
            $guidance | Should -Match "Permissions"
            $guidance | Should -Match "Schema existence"
            $guidance | Should -Match "Table name"
            $guidance | Should -Match "Data types"
            $guidance | Should -Match "Reserved words"
        }
    }

    Context "TableTruncate Operation Guidance" {
        It "Should provide truncate guidance" {
            # Arrange
            $context = @{
                SchemaName = 'dbo'
                TableName = 'Orders'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableTruncate" `
                                                   -ErrorMessage "Foreign key constraint" `
                                                   -Context $context

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "\[dbo\]\.\[Orders\]"
            $guidance | Should -Match "Foreign key"
            $guidance | Should -Match "constraint"
        }

        It "Should suggest alternatives for truncate failures" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableTruncate" `
                                                   -ErrorMessage "FK error" `
                                                   -Context @{SchemaName='s'; TableName='t'}

            # Assert
            $guidance | Should -Match "DELETE instead of TRUNCATE"
            $guidance | Should -Match "TableExistsAction='Recreate'"
        }

        It "Should include foreign key troubleshooting" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableTruncate" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{SchemaName='s'; TableName='t'}

            # Assert
            $guidance | Should -Match "Foreign key constraints"
            $guidance | Should -Match "Drop foreign keys"
        }
    }

    Context "TableDrop Operation Guidance" {
        It "Should provide drop table guidance" {
            # Arrange
            $context = @{
                SchemaName = 'staging'
                TableName = 'TempData'
            }

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableDrop" `
                                                   -ErrorMessage "Cannot drop table" `
                                                   -Context $context

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "\[staging\]\.\[TempData\]"
            $guidance | Should -Match "Cannot drop table"
        }

        It "Should warn about dependent objects" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableDrop" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{SchemaName='s'; TableName='t'}

            # Assert
            $guidance | Should -Match "Dependent objects"
            $guidance | Should -Match "Views"
            $guidance | Should -Match "stored procedures"
        }

        It "Should include permission guidance for drop" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "TableDrop" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{SchemaName='s'; TableName='t'}

            # Assert
            $guidance | Should -Match "Permissions"
            $guidance | Should -Match "ALTER.*SCHEMA"
        }
    }

    Context "Context Handling" {
        It "Should work with minimal context" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Error"

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "SQL Server"
        }

        It "Should use 'unknown' for missing context values" {
            # Arrange
            $context = @{}

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Schema" `
                                                   -ErrorMessage "Error" `
                                                   -Context $context

            # Assert
            $guidance | Should -Match "unknown"
        }

        It "Should handle null context gracefully" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Test error" `
                                                   -Context @{}

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
        }
    }

    Context "Output Format" {
        It "Should return non-empty string" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{Server='s'; Database='d'}

            # Assert
            $guidance | Should -BeOfType [string]
            $guidance.Length | Should -BeGreaterThan 50
        }

        It "Should include original error message" {
            # Arrange
            $errorMsg = "Specific error message ABC123"

            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Connection" `
                                                   -ErrorMessage $errorMsg `
                                                   -Context @{Server='s'; Database='d'}

            # Assert
            $guidance | Should -Match "Error details:"
            $guidance | Should -Match "ABC123"
        }

        It "Should have multi-line format" {
            # Act
            $guidance = Get-DatabaseErrorGuidance -Operation "Schema" `
                                                   -ErrorMessage "Error" `
                                                   -Context @{SchemaName='test'; Database='db'}

            # Assert
            $guidance | Should -Match "`n"
            ($guidance -split "`n").Count | Should -BeGreaterThan 5
        }
    }

    Context "Parameter Validation" {
        It "Should accept valid Operation values" {
            # Act & Assert
            { Get-DatabaseErrorGuidance -Operation "Connection" -ErrorMessage "test" } | Should -Not -Throw
            { Get-DatabaseErrorGuidance -Operation "Schema" -ErrorMessage "test" } | Should -Not -Throw
            { Get-DatabaseErrorGuidance -Operation "TableCreate" -ErrorMessage "test" } | Should -Not -Throw
            { Get-DatabaseErrorGuidance -Operation "TableTruncate" -ErrorMessage "test" } | Should -Not -Throw
            { Get-DatabaseErrorGuidance -Operation "TableDrop" -ErrorMessage "test" } | Should -Not -Throw
        }
    }
}
