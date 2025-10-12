# ConvertTo-BooleanValue.Tests.ps1
# Unit tests for ConvertTo-BooleanValue function
# Tests boolean conversion with multiple representations and error handling

BeforeAll {
    # Dot-source the function under test
    . "$PSScriptRoot/../../../../Private/DataImport/ConvertTo-BooleanValue.ps1"
}

Describe "ConvertTo-BooleanValue" {

    Context "True Values - Case Insensitive" {
        It "Should convert '1' to true" {
            $result = ConvertTo-BooleanValue -Value "1" -FieldName "Test"
            $result | Should -Be $true
        }

        It "Should convert 'TRUE' to true" {
            $result = ConvertTo-BooleanValue -Value "TRUE" -FieldName "Test"
            $result | Should -Be $true
        }

        It "Should convert 'true' (lowercase) to true" {
            $result = ConvertTo-BooleanValue -Value "true" -FieldName "Test"
            $result | Should -Be $true
        }

        It "Should convert 'YES' to true" {
            $result = ConvertTo-BooleanValue -Value "YES" -FieldName "Test"
            $result | Should -Be $true
        }

        It "Should convert 'Y' to true" {
            $result = ConvertTo-BooleanValue -Value "Y" -FieldName "Test"
            $result | Should -Be $true
        }

        It "Should convert 'T' to true" {
            $result = ConvertTo-BooleanValue -Value "T" -FieldName "Test"
            $result | Should -Be $true
        }
    }

    Context "False Values - Case Insensitive" {
        It "Should convert '0' to false" {
            $result = ConvertTo-BooleanValue -Value "0" -FieldName "Test"
            $result | Should -Be $false
        }

        It "Should convert 'FALSE' to false" {
            $result = ConvertTo-BooleanValue -Value "FALSE" -FieldName "Test"
            $result | Should -Be $false
        }

        It "Should convert 'false' (lowercase) to false" {
            $result = ConvertTo-BooleanValue -Value "false" -FieldName "Test"
            $result | Should -Be $false
        }

        It "Should convert 'NO' to false" {
            $result = ConvertTo-BooleanValue -Value "NO" -FieldName "Test"
            $result | Should -Be $false
        }

        It "Should convert 'N' to false" {
            $result = ConvertTo-BooleanValue -Value "N" -FieldName "Test"
            $result | Should -Be $false
        }

        It "Should convert 'F' to false" {
            $result = ConvertTo-BooleanValue -Value "F" -FieldName "Test"
            $result | Should -Be $false
        }
    }

    Context "Invalid Values - Should Throw" {
        It "Should throw for 'maybe'" {
            { ConvertTo-BooleanValue -Value "maybe" -FieldName "TestField" } |
                Should -Throw "*Invalid boolean value*"
        }

        It "Should throw for '2'" {
            { ConvertTo-BooleanValue -Value "2" -FieldName "TestField" } |
                Should -Throw "*Invalid boolean value*"
        }

        It "Should throw for empty string" {
            { ConvertTo-BooleanValue -Value "" -FieldName "TestField" } |
                Should -Throw "*Invalid boolean value*"
        }

        It "Should throw for whitespace" {
            { ConvertTo-BooleanValue -Value "   " -FieldName "TestField" } |
                Should -Throw "*Invalid boolean value*"
        }

        It "Should throw for 'NULL'" {
            { ConvertTo-BooleanValue -Value "NULL" -FieldName "TestField" } |
                Should -Throw "*Invalid boolean value*"
        }
    }

    Context "Error Message Context" {
        It "Should include field name in error message" {
            { ConvertTo-BooleanValue -Value "invalid" -FieldName "IsActive" -LineNumber 42 } |
                Should -Throw "*IsActive*"
        }

        It "Should include line number in error message" {
            { ConvertTo-BooleanValue -Value "invalid" -FieldName "IsActive" -LineNumber 42 } |
                Should -Throw "*42*"
        }

        It "Should list valid values in error message" {
            { ConvertTo-BooleanValue -Value "invalid" -FieldName "Test" } |
                Should -Throw "*TRUE/FALSE*"
        }
    }
}
