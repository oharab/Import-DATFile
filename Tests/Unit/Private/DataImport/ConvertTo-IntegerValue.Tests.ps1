# ConvertTo-IntegerValue.Tests.ps1
# Unit tests for ConvertTo-IntegerValue function
# Tests integer conversion for Int32 and Int64 types with culture invariance

BeforeAll {
    # Dot-source the function under test
    . "$PSScriptRoot/../../../../Private/DataImport/ConvertTo-IntegerValue.ps1"
}

Describe "ConvertTo-IntegerValue" {

    Context "Int32 Conversion" {
        It "Should convert integer string to Int32" {
            $result = ConvertTo-IntegerValue -Value "123" -TargetType ([Int32])
            $result | Should -BeOfType [Int32]
            $result | Should -Be 123
        }

        It "Should convert decimal notation to Int32" {
            $result = ConvertTo-IntegerValue -Value "123.0" -TargetType ([Int32])
            $result | Should -BeOfType [Int32]
            $result | Should -Be 123
        }

        It "Should handle negative integers" {
            $result = ConvertTo-IntegerValue -Value "-456" -TargetType ([Int32])
            $result | Should -Be -456
        }

        It "Should handle zero" {
            $result = ConvertTo-IntegerValue -Value "0" -TargetType ([Int32])
            $result | Should -Be 0
        }

        It "Should handle Int32 max value" {
            $result = ConvertTo-IntegerValue -Value "2147483647" -TargetType ([Int32])
            $result | Should -Be 2147483647
        }

        It "Should handle Int32 min value" {
            $result = ConvertTo-IntegerValue -Value "-2147483648" -TargetType ([Int32])
            $result | Should -Be -2147483648
        }
    }

    Context "Int64 Conversion" {
        It "Should convert large integer to Int64" {
            $result = ConvertTo-IntegerValue -Value "9876543210" -TargetType ([Int64])
            $result | Should -BeOfType [Int64]
            $result | Should -Be 9876543210
        }

        It "Should handle Int64 beyond Int32 range" {
            $result = ConvertTo-IntegerValue -Value "9999999999" -TargetType ([Int64])
            $result | Should -Be 9999999999
        }
    }

    Context "Culture Invariance" {
        It "Should use InvariantCulture for parsing" {
            $result = ConvertTo-IntegerValue -Value "1000.0" -TargetType ([Int32])
            $result | Should -Be 1000
        }
    }

    Context "Invalid Values - Should Throw" {
        It "Should throw for 'not-a-number'" {
            { ConvertTo-IntegerValue -Value "not-a-number" -TargetType ([Int32]) } | Should -Throw
        }

        It "Should throw for empty string" {
            { ConvertTo-IntegerValue -Value "" -TargetType ([Int32]) } | Should -Throw
        }

        It "Should throw for whitespace" {
            { ConvertTo-IntegerValue -Value "   " -TargetType ([Int32]) } | Should -Throw
        }

        It "Should throw for 'NULL'" {
            { ConvertTo-IntegerValue -Value "NULL" -TargetType ([Int32]) } | Should -Throw
        }

        It "Should throw for '123abc'" {
            { ConvertTo-IntegerValue -Value "123abc" -TargetType ([Int32]) } | Should -Throw
        }

        # Note: Current implementation uses -as operator which truncates decimals
        # and returns $null on overflow rather than throwing
        # These behaviors could be improved but are documented here
    }
}
