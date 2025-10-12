# Get-ConversionGuidance.Tests.ps1
# Unit tests for Get-ConversionGuidance function

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"

    # Dot-source the function
    . (Join-Path $moduleRoot "Private\DataImport\Get-ConversionGuidance.ps1")
}

Describe "Get-ConversionGuidance" {

    Context "Integer Conversion Guidance" {
        It "Should provide guidance for invalid integer value" {
            # Act
            $guidance = Get-ConversionGuidance -Value "abc" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "EmployeeID" `
                                               -TableName "Employee" `
                                               -RowNumber 5

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "Table 'Employee'"
            $guidance | Should -Match "Field 'EmployeeID'"
            $guidance | Should -Match "Row 5"
            $guidance | Should -Match "integer"
            $guidance | Should -Match "abc"
        }

        It "Should include decimal notation guidance for integers" {
            # Act
            $guidance = Get-ConversionGuidance -Value "123.45" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "Count"

            # Assert
            $guidance | Should -Match "decimal notation.*123\.0"
        }

        It "Should work for Int64 type" {
            # Act
            $guidance = Get-ConversionGuidance -Value "invalid" `
                                               -TargetType ([System.Int64]) `
                                               -FieldName "LargeNumber"

            # Assert
            $guidance | Should -Match "integer"
            $guidance | Should -Match "LargeNumber"
        }
    }

    Context "Decimal Conversion Guidance" {
        It "Should provide guidance for invalid decimal value" {
            # Act
            $guidance = Get-ConversionGuidance -Value "12,34" `
                                               -TargetType ([System.Decimal]) `
                                               -FieldName "Price" `
                                               -TableName "Product" `
                                               -RowNumber 10

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "Table 'Product'"
            $guidance | Should -Match "Field 'Price'"
            $guidance | Should -Match "Row 10"
            $guidance | Should -Match "decimal"
            $guidance | Should -Match "decimal point separator"
        }

        It "Should warn about comma separators" {
            # Act
            $guidance = Get-ConversionGuidance -Value "1,234.56" `
                                               -TargetType ([System.Decimal]) `
                                               -FieldName "Amount"

            # Assert
            $guidance | Should -Match "Wrong decimal separator"
            $guidance | Should -Match "period.*\."
        }

        It "Should work for Double type" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Double]) `
                                               -FieldName "Rate"

            # Assert
            $guidance | Should -Match "decimal"
            $guidance | Should -Match "Rate"
        }

        It "Should work for Single type" {
            # Act
            $guidance = Get-ConversionGuidance -Value "xyz" `
                                               -TargetType ([System.Single]) `
                                               -FieldName "Float"

            # Assert
            $guidance | Should -Match "decimal"
            $guidance | Should -Match "Float"
        }
    }

    Context "DateTime Conversion Guidance" {
        It "Should provide guidance for invalid date value" {
            # Act
            $guidance = Get-ConversionGuidance -Value "2024-13-45" `
                                               -TargetType ([System.DateTime]) `
                                               -FieldName "HireDate" `
                                               -TableName "Employee" `
                                               -RowNumber 3

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "Table 'Employee'"
            $guidance | Should -Match "Field 'HireDate'"
            $guidance | Should -Match "Row 3"
            $guidance | Should -Match "ISO 8601"
            $guidance | Should -Match "yyyy-MM-dd"
        }

        It "Should list supported date formats" {
            # Act
            $guidance = Get-ConversionGuidance -Value "01/15/2024" `
                                               -TargetType ([System.DateTime]) `
                                               -FieldName "BirthDate"

            # Assert
            $guidance | Should -Match "yyyy-MM-dd HH:mm:ss"
            $guidance | Should -Match "yyyy-MM-dd"
            $guidance | Should -Match "supported format"
        }
    }

    Context "Boolean Conversion Guidance" {
        It "Should provide guidance for invalid boolean value" {
            # Act
            $guidance = Get-ConversionGuidance -Value "maybe" `
                                               -TargetType ([System.Boolean]) `
                                               -FieldName "IsActive" `
                                               -TableName "User" `
                                               -RowNumber 7

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "Table 'User'"
            $guidance | Should -Match "Field 'IsActive'"
            $guidance | Should -Match "Row 7"
            $guidance | Should -Match "boolean"
            $guidance | Should -Match "maybe"
        }

        It "Should list accepted boolean values" {
            # Act
            $guidance = Get-ConversionGuidance -Value "yes/no" `
                                               -TargetType ([System.Boolean]) `
                                               -FieldName "Flag"

            # Assert
            $guidance | Should -Match "TRUE.*FALSE"
            $guidance | Should -Match "1.*0"
            $guidance | Should -Match "YES.*NO"
            $guidance | Should -Match "Y.*N"
        }
    }

    Context "Context Building" {
        It "Should include all context fields when provided" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "TestField" `
                                               -TableName "TestTable" `
                                               -RowNumber 99

            # Assert
            $guidance | Should -Match "Table 'TestTable'"
            $guidance | Should -Match "Field 'TestField'"
            $guidance | Should -Match "Row 99"
        }

        It "Should work without table name" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "TestField" `
                                               -RowNumber 5

            # Assert
            $guidance | Should -Not -Match "Table"
            $guidance | Should -Match "Field 'TestField'"
            $guidance | Should -Match "Row 5"
        }

        It "Should work without row number" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "TestField" `
                                               -TableName "TestTable"

            # Assert
            $guidance | Should -Match "Table 'TestTable'"
            $guidance | Should -Match "Field 'TestField'"
            $guidance | Should -Not -Match "Row \d+"
        }

        It "Should work with minimal context" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "TestField"

            # Assert
            $guidance | Should -Not -BeNullOrEmpty
            $guidance | Should -Match "Field 'TestField'"
            $guidance | Should -Match "integer"
        }
    }

    Context "Output Format" {
        It "Should return non-empty string" {
            # Act
            $guidance = Get-ConversionGuidance -Value "bad" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "Test"

            # Assert
            $guidance | Should -BeOfType [string]
            $guidance.Length | Should -BeGreaterThan 20
        }

        It "Should include original value in guidance" {
            # Act
            $guidance = Get-ConversionGuidance -Value "BadValue123" `
                                               -TargetType ([System.Int32]) `
                                               -FieldName "Test"

            # Assert
            $guidance | Should -Match "BadValue123"
        }
    }
}
