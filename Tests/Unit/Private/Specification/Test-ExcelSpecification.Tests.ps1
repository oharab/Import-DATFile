# Test-ExcelSpecification.Tests.ps1
# Unit tests for Test-ExcelSpecification function

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"

    # Dot-source the function
    . (Join-Path $moduleRoot "Private\Specification\Test-ExcelSpecification.ps1")
}

Describe "Test-ExcelSpecification" {

    Context "Valid Specifications" {
        It "Should validate correct specification" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                    Scale = $null
                },
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'Age'
                    'Data type' = 'INT'
                    Precision = $null
                    Scale = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
            $result.Errors.Count | Should -Be 0
            $result.Warnings.Count | Should -Be 0
        }

        It "Should accept all valid SQL data types" {
            # Arrange
            $validTypes = @('VARCHAR', 'NVARCHAR', 'INT', 'BIGINT', 'DECIMAL', 'DATETIME', 'BIT')
            $specs = $validTypes | ForEach-Object {
                [PSCustomObject]@{
                    'Table name' = 'Test'
                    'Column name' = "Field$_"
                    'Data type' = $_
                    Precision = if ($_ -in @('VARCHAR', 'NVARCHAR')) { 100 } elseif ($_ -eq 'DECIMAL') { 18 } else { $null }
                    Scale = if ($_ -eq 'DECIMAL') { 2 } else { $null }
                }
            }

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
        }
    }

    Context "Empty or Missing Data" {
        It "Should fail for empty specifications array" {
            # Arrange
            $specs = @()

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "empty.*no data rows"
        }

        It "Should throw on empty specs with ThrowOnError" {
            # Arrange
            $specs = @()

            # Act & Assert
            { Test-ExcelSpecification -Specifications $specs -ThrowOnError } |
                Should -Throw "*empty*"
        }
    }

    Context "Missing Required Columns" {
        It "Should fail when Table name is empty" {
            # Arrange - Note: Column normalization happens in Get-TableSpecifications
            # Test validates empty values, not missing properties
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = ''
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    'Precision' = $null
                    'Scale' = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors -join ' ' | Should -Match "'Table name' is empty or missing"
        }

        It "Should fail when Column name is empty" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = ''
                    'Data type' = 'VARCHAR'
                    'Precision' = $null
                    'Scale' = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "'Column name' is empty or missing"
        }

        It "Should fail when Data type is empty" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = ''
                    'Precision' = $null
                    'Scale' = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "'Data type' is empty or missing"
        }
    }

    Context "Table Name Validation" {
        It "Should fail for empty table name" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = ''
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Table name.*empty"
        }

        It "Should fail for invalid table name with special characters" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee-Table'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Invalid table name.*Employee-Table"
        }
    }

    Context "Column Name Validation" {
        It "Should fail for empty column name" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = ''
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Column name.*empty"
        }

        It "Should fail for invalid column name with spaces" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'First Name'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Invalid column name.*First Name"
        }

        It "Should warn for SQL reserved keywords" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'SELECT'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
            $result.Warnings.Count | Should -BeGreaterThan 0
            $result.Warnings[0] | Should -Match "Row 2.*SELECT.*reserved keyword"
        }
    }

    Context "Data Type Validation" {
        It "Should fail for empty data type" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = ''
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Data type.*empty"
        }

        It "Should fail for invalid data type" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'STRING'
                    Precision = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Invalid data type.*STRING"
        }
    }

    Context "Precision Validation" {
        It "Should warn when VARCHAR missing precision (will use default)" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    'Precision' = $null
                    'Scale' = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
            $result.Warnings[0] | Should -Match "Row 2.*No precision specified.*VARCHAR.*default"
        }

        It "Should fail when DECIMAL missing precision" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Product'
                    'Column name' = 'Price'
                    'Data type' = 'DECIMAL'
                    Precision = $null
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*DECIMAL.*requires.*Precision"
        }

        It "Should fail for non-numeric precision" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 'abc'
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Precision.*abc.*not.*valid integer"
        }

        It "Should warn for VARCHAR precision exceeding 8000" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'Notes'
                    'Data type' = 'VARCHAR'
                    Precision = 9000
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
            $result.Warnings.Count | Should -BeGreaterThan 0
            $result.Warnings[0] | Should -Match "Row 2.*Precision.*9000.*exceeds.*8000"
        }

        It "Should fail for DECIMAL precision exceeding 38" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Product'
                    'Column name' = 'Price'
                    'Data type' = 'DECIMAL'
                    Precision = 40
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Precision.*40.*exceeds.*38"
        }
    }

    Context "Scale Validation" {
        It "Should fail when scale exceeds precision for DECIMAL" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Product'
                    'Column name' = 'Price'
                    'Data type' = 'DECIMAL'
                    Precision = 10
                    Scale = 15
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Scale.*15.*cannot exceed.*Precision.*10"
        }

        It "Should fail for negative scale" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Product'
                    'Column name' = 'Price'
                    'Data type' = 'DECIMAL'
                    Precision = 10
                    Scale = -5
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 2.*Scale.*>= 0"
        }
    }

    Context "Duplicate Field Detection" {
        It "Should fail for duplicate field definitions" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                },
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 100
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $false
            $result.Errors[0] | Should -Match "Row 3.*Duplicate.*Employee.*FirstName.*row 2"
        }

        It "Should allow same column name in different tables" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'Name'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                },
                [PSCustomObject]@{
                    'Table name' = 'Department'
                    'Column name' = 'Name'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.IsValid | Should -Be $true
        }
    }

    Context "ThrowOnError Parameter" {
        It "Should throw exception when validation fails and ThrowOnError is set" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = ''
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                }
            )

            # Act & Assert
            { Test-ExcelSpecification -Specifications $specs -ThrowOnError } |
                Should -Throw "*validation failed*"
        }

        It "Should not throw when validation passes with ThrowOnError set" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act & Assert
            { Test-ExcelSpecification -Specifications $specs -ThrowOnError } |
                Should -Not -Throw
        }
    }

    Context "Return Value Structure" {
        It "Should return hashtable with required keys" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert
            $result.Keys | Should -Contain 'IsValid'
            $result.Keys | Should -Contain 'Errors'
            $result.Keys | Should -Contain 'Warnings'
        }

        It "Should return collections for Errors and Warnings" {
            # Arrange
            $specs = @(
                [PSCustomObject]@{
                    'Table name' = 'Employee'
                    'Column name' = 'FirstName'
                    'Data type' = 'VARCHAR'
                    Precision = 50
                }
            )

            # Act
            $result = Test-ExcelSpecification -Specifications $specs

            # Assert - Should have collections even if empty
            $result.ContainsKey('Errors') | Should -Be $true
            $result.ContainsKey('Warnings') | Should -Be $true
            $result.Errors.Count | Should -Be 0
            $result.Warnings.Count | Should -Be 0
        }
    }
}
