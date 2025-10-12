# ConvertTo-DateTimeValue.Tests.ps1
# Unit tests for ConvertTo-DateTimeValue function
# Tests datetime parsing with multiple ISO 8601 formats and culture invariance

BeforeAll {
    # Dot-source the function under test
    . "$PSScriptRoot/../../../../Private/DataImport/ConvertTo-DateTimeValue.ps1"
}

Describe "ConvertTo-DateTimeValue" {

    Context "Supported ISO 8601 Formats" {
        It "Should parse datetime with 3-digit milliseconds" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 10:30:45.123"
            $result | Should -BeOfType [DateTime]
            $result.Year | Should -Be 2024
            $result.Month | Should -Be 1
            $result.Day | Should -Be 15
            $result.Hour | Should -Be 10
            $result.Minute | Should -Be 30
            $result.Second | Should -Be 45
            $result.Millisecond | Should -Be 123
        }

        It "Should parse datetime with 2-digit milliseconds" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 10:30:45.12"
            $result | Should -BeOfType [DateTime]
            $result.Millisecond | Should -Be 120
        }

        It "Should parse datetime with 1-digit milliseconds" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 10:30:45.1"
            $result | Should -BeOfType [DateTime]
            $result.Millisecond | Should -Be 100
        }

        It "Should parse datetime without milliseconds" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 10:30:45"
            $result.Hour | Should -Be 10
            $result.Minute | Should -Be 30
            $result.Second | Should -Be 45
        }

        It "Should parse date only" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15"
            $result.Date | Should -Be ([DateTime]"2024-01-15").Date
            $result.Hour | Should -Be 0
        }
    }

    Context "Culture Invariance" {
        It "Should use InvariantCulture for parsing (month-day order)" {
            $result = ConvertTo-DateTimeValue -Value "2024-12-31"
            $result.Month | Should -Be 12
            $result.Day | Should -Be 31
        }

        It "Should not accept European format (day-month-year)" {
            { ConvertTo-DateTimeValue -Value "31-12-2024" } | Should -Throw
        }
    }

    Context "Invalid Formats - Should Throw" {
        It "Should throw for '2024/01/15'" {
            { ConvertTo-DateTimeValue -Value "2024/01/15" } | Should -Throw
        }

        It "Should throw for 'Jan 15 2024'" {
            { ConvertTo-DateTimeValue -Value "Jan 15 2024" } | Should -Throw
        }

        It "Should throw for 'not-a-date'" {
            { ConvertTo-DateTimeValue -Value "not-a-date" } | Should -Throw
        }

        It "Should throw for '15-01-2024'" {
            { ConvertTo-DateTimeValue -Value "15-01-2024" } | Should -Throw
        }

        It "Should throw for empty string" {
            { ConvertTo-DateTimeValue -Value "" } | Should -Throw
        }

        It "Should throw for invalid month" {
            { ConvertTo-DateTimeValue -Value "2024-13-01" } | Should -Throw
        }

        It "Should throw for invalid day" {
            { ConvertTo-DateTimeValue -Value "2024-01-32" } | Should -Throw
        }
    }

    Context "Edge Cases" {
        It "Should handle leap year dates" {
            $result = ConvertTo-DateTimeValue -Value "2024-02-29"
            $result.Month | Should -Be 2
            $result.Day | Should -Be 29
        }

        It "Should throw for invalid leap year date" {
            { ConvertTo-DateTimeValue -Value "2023-02-29" } | Should -Throw
        }

        It "Should handle midnight" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 00:00:00"
            $result.Hour | Should -Be 0
            $result.Minute | Should -Be 0
        }

        It "Should handle 23:59:59" {
            $result = ConvertTo-DateTimeValue -Value "2024-01-15 23:59:59"
            $result.Hour | Should -Be 23
        }
    }
}
