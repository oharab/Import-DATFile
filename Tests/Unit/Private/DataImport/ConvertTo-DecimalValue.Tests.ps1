# ConvertTo-DecimalValue.Tests.ps1
# Unit tests for ConvertTo-DecimalValue function
# Tests decimal/floating-point conversion for Decimal, Double, and Single types

BeforeAll {
    # Dot-source the function under test
    . "$PSScriptRoot/../../../../Private/DataImport/ConvertTo-DecimalValue.ps1"
}

Describe "ConvertTo-DecimalValue" {

    Context "Decimal Conversion" {
        It "Should convert decimal string" {
            $result = ConvertTo-DecimalValue -Value "123.45" -TargetType ([Decimal])
            $result | Should -BeOfType [Decimal]
            $result | Should -Be 123.45
        }

        It "Should handle many decimal places" {
            $result = ConvertTo-DecimalValue -Value "99.9999" -TargetType ([Decimal])
            $result | Should -Be 99.9999
        }

        It "Should handle negative decimals" {
            $result = ConvertTo-DecimalValue -Value "-45.67" -TargetType ([Decimal])
            $result | Should -Be -45.67
        }

        It "Should handle whole numbers" {
            $result = ConvertTo-DecimalValue -Value "100" -TargetType ([Decimal])
            $result | Should -Be 100
        }

        It "Should handle zero" {
            $result = ConvertTo-DecimalValue -Value "0.00" -TargetType ([Decimal])
            $result | Should -Be 0
        }
    }

    Context "Double Conversion" {
        It "Should convert to Double" {
            $result = ConvertTo-DecimalValue -Value "123.456789" -TargetType ([Double])
            $result | Should -BeOfType [Double]
            $result | Should -Be 123.456789
        }

        It "Should handle scientific notation for Double" {
            $result = ConvertTo-DecimalValue -Value "1.23E+10" -TargetType ([Double])
            $result | Should -BeGreaterThan 1.2e10
        }

        It "Should handle very small numbers" {
            $result = ConvertTo-DecimalValue -Value "0.0000001" -TargetType ([Double])
            $result | Should -Be 0.0000001
        }
    }

    Context "Single Conversion" {
        It "Should convert to Single" {
            $result = ConvertTo-DecimalValue -Value "123.45" -TargetType ([Single])
            $result | Should -BeOfType [Single]
            [Math]::Abs($result - 123.45) | Should -BeLessThan 0.01
        }
    }

    Context "Culture Invariance" {
        It "Should use period as decimal separator (not comma)" {
            $result = ConvertTo-DecimalValue -Value "123.45" -TargetType ([Decimal])
            $result | Should -Be 123.45
        }

        # Note: PowerShell's Parse with InvariantCulture treats comma as thousands separator
        # "123,45" parses as 12345, not as error. This is documented behavior.
    }

    Context "Invalid Values - Should Throw" {
        It "Should throw for 'not-a-number'" {
            { ConvertTo-DecimalValue -Value "not-a-number" -TargetType ([Decimal]) } | Should -Throw
        }

        It "Should throw for empty string" {
            { ConvertTo-DecimalValue -Value "" -TargetType ([Decimal]) } | Should -Throw
        }

        It "Should throw for whitespace" {
            { ConvertTo-DecimalValue -Value "   " -TargetType ([Decimal]) } | Should -Throw
        }

        It "Should throw for 'NULL'" {
            { ConvertTo-DecimalValue -Value "NULL" -TargetType ([Decimal]) } | Should -Throw
        }

        It "Should throw for '123abc'" {
            { ConvertTo-DecimalValue -Value "123abc" -TargetType ([Decimal]) } | Should -Throw
        }
    }

    Context "Unsupported Types - Should Throw" {
        It "Should throw for unsupported target type String" {
            { ConvertTo-DecimalValue -Value "123" -TargetType ([String]) } |
                Should -Throw "*Unsupported*"
        }

        It "Should throw for unsupported target type Int32" {
            { ConvertTo-DecimalValue -Value "123" -TargetType ([Int32]) } |
                Should -Throw "*Unsupported*"
        }
    }
}
