# ConvertTo-TypedValue.Tests.ps1
# Characterization tests for ConvertTo-TypedValue function
# These tests document CURRENT behavior to provide a safety net for refactoring

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\.."

    # Dot-source Private functions needed for testing
    . (Join-Path $moduleRoot "Private\DataImport\Test-IsNullValue.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\ConvertTo-DateTimeValue.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\ConvertTo-IntegerValue.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\ConvertTo-DecimalValue.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\ConvertTo-BooleanValue.ps1")
    . (Join-Path $moduleRoot "Private\DataImport\ConvertTo-TypedValue.ps1")
}

Describe "ConvertTo-TypedValue" {

    Context "DateTime Conversion" {
        It "Should convert ISO 8601 datetime with milliseconds" {
            $dateValue = "2024-01-15 10:30:45.123"
            $result = ConvertTo-TypedValue -Value $dateValue -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -BeOfType [System.DateTime]
            $result.Year | Should -Be 2024
            $result.Month | Should -Be 1
            $result.Day | Should -Be 15
            $result.Hour | Should -Be 10
            $result.Minute | Should -Be 30
            $result.Second | Should -Be 45
        }

        It "Should convert ISO 8601 datetime without milliseconds" {
            $dateValue = "2024-01-15 10:30:45"
            $result = ConvertTo-TypedValue -Value $dateValue -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -BeOfType [System.DateTime]
            $result.Year | Should -Be 2024
        }

        It "Should convert ISO 8601 date only" {
            $dateValue = "2024-01-15"
            $result = ConvertTo-TypedValue -Value $dateValue -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -BeOfType [System.DateTime]
            $result.Date | Should -Be ([DateTime]"2024-01-15").Date
        }

        It "Should return DBNull for empty datetime string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for NULL datetime string" {
            $result = ConvertTo-TypedValue -Value "NULL" -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for whitespace datetime string" {
            $result = ConvertTo-TypedValue -Value "   " -TargetType ([System.DateTime]) -FieldName "TestDate"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Int32 Conversion" {
        It "Should convert integer string to Int32" {
            $intValue = "123"
            $result = ConvertTo-TypedValue -Value $intValue -TargetType ([System.Int32]) -FieldName "TestInt"

            $result | Should -BeOfType [System.Int32]
            $result | Should -Be 123
        }

        It "Should convert decimal notation to Int32" {
            $intValue = "123.0"
            $result = ConvertTo-TypedValue -Value $intValue -TargetType ([System.Int32]) -FieldName "TestInt"

            $result | Should -BeOfType [System.Int32]
            $result | Should -Be 123
        }

        It "Should convert negative integer" {
            $intValue = "-456"
            $result = ConvertTo-TypedValue -Value $intValue -TargetType ([System.Int32]) -FieldName "TestInt"

            $result | Should -Be -456
        }

        It "Should return DBNull for empty integer string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Int32]) -FieldName "TestInt"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for NULL integer string" {
            $result = ConvertTo-TypedValue -Value "NULL" -TargetType ([System.Int32]) -FieldName "TestInt"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Int64 Conversion" {
        It "Should convert large integer string to Int64" {
            $longValue = "9876543210"
            $result = ConvertTo-TypedValue -Value $longValue -TargetType ([System.Int64]) -FieldName "TestLong"

            $result | Should -BeOfType [System.Int64]
            $result | Should -Be 9876543210
        }

        It "Should convert decimal notation to Int64" {
            $longValue = "123.0"
            $result = ConvertTo-TypedValue -Value $longValue -TargetType ([System.Int64]) -FieldName "TestLong"

            $result | Should -BeOfType [System.Int64]
            $result | Should -Be 123
        }

        It "Should return DBNull for empty Int64 string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Int64]) -FieldName "TestLong"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Decimal Conversion" {
        It "Should convert decimal string with period separator" {
            $decimalValue = "123.45"
            $result = ConvertTo-TypedValue -Value $decimalValue -TargetType ([System.Decimal]) -FieldName "TestDecimal"

            $result | Should -BeOfType [System.Decimal]
            $result | Should -Be 123.45
        }

        It "Should convert decimal with many decimal places" {
            $decimalValue = "99.9999"
            $result = ConvertTo-TypedValue -Value $decimalValue -TargetType ([System.Decimal]) -FieldName "TestDecimal"

            $result | Should -Be 99.9999
        }

        It "Should convert negative decimal" {
            $decimalValue = "-45.67"
            $result = ConvertTo-TypedValue -Value $decimalValue -TargetType ([System.Decimal]) -FieldName "TestDecimal"

            $result | Should -Be -45.67
        }

        It "Should return DBNull for empty decimal string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Decimal]) -FieldName "TestDecimal"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Double Conversion" {
        It "Should convert double string" {
            $doubleValue = "123.456789"
            $result = ConvertTo-TypedValue -Value $doubleValue -TargetType ([System.Double]) -FieldName "TestDouble"

            $result | Should -BeOfType [System.Double]
            $result | Should -Be 123.456789
        }

        It "Should return DBNull for empty double string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Double]) -FieldName "TestDouble"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Single Conversion" {
        It "Should convert float string" {
            $floatValue = "123.45"
            $result = ConvertTo-TypedValue -Value $floatValue -TargetType ([System.Single]) -FieldName "TestFloat"

            $result | Should -BeOfType [System.Single]
        }

        It "Should return DBNull for empty float string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Single]) -FieldName "TestFloat"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Boolean Conversion" {
        It "Should convert '1' to true" {
            $result = ConvertTo-TypedValue -Value "1" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -BeOfType [System.Boolean]
            $result | Should -Be $true
        }

        It "Should convert 'TRUE' to true" {
            $result = ConvertTo-TypedValue -Value "TRUE" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $true
        }

        It "Should convert 'true' to true (case insensitive)" {
            $result = ConvertTo-TypedValue -Value "true" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $true
        }

        It "Should convert 'YES' to true" {
            $result = ConvertTo-TypedValue -Value "YES" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $true
        }

        It "Should convert 'Y' to true" {
            $result = ConvertTo-TypedValue -Value "Y" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $true
        }

        It "Should convert 'T' to true" {
            $result = ConvertTo-TypedValue -Value "T" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $true
        }

        It "Should convert '0' to false" {
            $result = ConvertTo-TypedValue -Value "0" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $false
        }

        It "Should convert 'FALSE' to false" {
            $result = ConvertTo-TypedValue -Value "FALSE" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $false
        }

        It "Should convert 'NO' to false" {
            $result = ConvertTo-TypedValue -Value "NO" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $false
        }

        It "Should convert 'N' to false" {
            $result = ConvertTo-TypedValue -Value "N" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $false
        }

        It "Should convert 'F' to false" {
            $result = ConvertTo-TypedValue -Value "F" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be $false
        }

        It "Should return DBNull for empty boolean string" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.Boolean]) -FieldName "TestBool"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "String Conversion (Default)" {
        It "Should return string value unchanged" {
            $stringValue = "Hello World"
            $result = ConvertTo-TypedValue -Value $stringValue -TargetType ([System.String]) -FieldName "TestString"

            $result | Should -BeOfType [System.String]
            $result | Should -Be "Hello World"
        }

        It "Should preserve whitespace in string values" {
            $stringValue = "  Padded String  "
            $result = ConvertTo-TypedValue -Value $stringValue -TargetType ([System.String]) -FieldName "TestString"

            $result | Should -Be "  Padded String  "
        }

        It "Should return DBNull for empty string when type is String" {
            $result = ConvertTo-TypedValue -Value "" -TargetType ([System.String]) -FieldName "TestString"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "NULL Value Handling" {
        It "Should return DBNull for 'NULL' string (case insensitive)" {
            $result = ConvertTo-TypedValue -Value "NULL" -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for 'null' string" {
            $result = ConvertTo-TypedValue -Value "null" -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for 'NA' string" {
            $result = ConvertTo-TypedValue -Value "NA" -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for 'N/A' string" {
            $result = ConvertTo-TypedValue -Value "N/A" -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for whitespace-only string" {
            $result = ConvertTo-TypedValue -Value "   " -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }

        It "Should return DBNull for tab and space whitespace" {
            $result = ConvertTo-TypedValue -Value "`t  `t" -TargetType ([System.String]) -FieldName "TestField"

            $result | Should -Be ([DBNull]::Value)
        }
    }

    Context "Error Handling" {
        It "Should return original string on conversion error with warning" {
            $invalidDate = "not-a-valid-date"
            $result = ConvertTo-TypedValue -Value $invalidDate -TargetType ([System.DateTime]) -FieldName "TestDate" -WarningAction SilentlyContinue

            # Current behavior: returns original string on error
            $result | Should -Be "not-a-valid-date"
        }

        It "Should return original string on invalid integer conversion" {
            $invalidInt = "not-an-integer"
            $result = ConvertTo-TypedValue -Value $invalidInt -TargetType ([System.Int32]) -FieldName "TestInt" -WarningAction SilentlyContinue

            # Current behavior: returns original string on error
            $result | Should -Be "not-an-integer"
        }
    }
}
