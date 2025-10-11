# Read-DatFileLines.Tests.ps1
# Characterization tests for Read-DatFileLines function
# Tests document CURRENT multi-line parsing behavior

BeforeAll {
    # Import the main module first (loads dependencies and constants)
    $moduleRoot = Join-Path $PSScriptRoot "..\..\..\..\"
    $modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
    Import-Module $modulePath -Force

    # Dot-source the private function directly for testing
    $functionPath = Join-Path $moduleRoot "Private\DataImport\Read-DatFileLines.ps1"
    . $functionPath
}

Describe "Read-DatFileLines" {

    Context "Single-line Records" {
        It "Should parse simple pipe-separated record" {
            # Arrange
            $testFile = Join-Path $TestDrive "simple.dat"
            $content = "ID001|John|Doe|2024-01-15"
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 4

            # Assert
            $result.Count | Should -Be 1
            $result[0].Values.Count | Should -Be 4
            $result[0].Values[0] | Should -Be "ID001"
            $result[0].Values[1] | Should -Be "John"
            $result[0].Values[2] | Should -Be "Doe"
            $result[0].Values[3] | Should -Be "2024-01-15"
            $result[0].LineNumber | Should -Be 1
        }

        It "Should parse multiple single-line records" {
            # Arrange
            $testFile = Join-Path $TestDrive "multiple.dat"
            $content = @(
                "ID001|John|Doe|2024-01-15",
                "ID002|Jane|Smith|2024-01-16",
                "ID003|Bob|Johnson|2024-01-17"
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 4

            # Assert
            $result.Count | Should -Be 3
            $result[0].Values[0] | Should -Be "ID001"
            $result[1].Values[0] | Should -Be "ID002"
            $result[2].Values[0] | Should -Be "ID003"
            $result[0].LineNumber | Should -Be 1
            $result[1].LineNumber | Should -Be 2
            $result[2].LineNumber | Should -Be 3
        }

        It "Should handle records with empty fields" {
            # Arrange
            $testFile = Join-Path $TestDrive "empty-fields.dat"
            $content = "ID001||Doe|"
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 4

            # Assert
            $result.Count | Should -Be 1
            $result[0].Values[0] | Should -Be "ID001"
            $result[0].Values[1] | Should -Be ""
            $result[0].Values[2] | Should -Be "Doe"
            $result[0].Values[3] | Should -Be ""
        }

        It "Should preserve trailing pipe fields" {
            # Arrange
            $testFile = Join-Path $TestDrive "trailing.dat"
            $content = "ID001|Data|More|"
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 4

            # Assert
            $result.Count | Should -Be 1
            $result[0].Values.Count | Should -Be 4
            $result[0].Values[3] | Should -Be ""
        }
    }

    Context "Multi-line Records" {
        It "Should accumulate lines when field count insufficient" {
            # Arrange
            $testFile = Join-Path $TestDrive "multiline.dat"
            $content = @(
                "ID001|First line",
                "continues here|2024-01-15|Complete"
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 4

            # Assert
            $result.Count | Should -Be 1
            $result[0].LineNumber | Should -Be 1
            $result[0].Values.Count | Should -Be 4
            $result[0].Values[1] | Should -Match "First line`ncontinues here"
        }

        It "Should handle record spanning three lines" {
            # Arrange
            $testFile = Join-Path $TestDrive "threeline.dat"
            $content = @(
                "ID001|Line1",
                "Line2",
                "Line3|Final"
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 1
            $result[0].LineNumber | Should -Be 1
            $result[0].Values[1] | Should -Match "Line1`nLine2`nLine3"
        }

        It "Should handle mix of single-line and multi-line records" {
            # Arrange
            $testFile = Join-Path $TestDrive "mixed.dat"
            $content = @(
                "ID001|SingleLine|Data",
                "ID002|Multi",
                "Line|Data",
                "ID003|AnotherSingle|Data"
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 3
            $result[0].Values[0] | Should -Be "ID001"
            $result[0].LineNumber | Should -Be 1
            $result[1].Values[0] | Should -Be "ID002"
            $result[1].LineNumber | Should -Be 2
            $result[1].Values[1] | Should -Match "Multi`nLine"
            $result[2].Values[0] | Should -Be "ID003"
            $result[2].LineNumber | Should -Be 4
        }
    }

    Context "Empty Lines and Whitespace" {
        It "Should skip empty lines" {
            # Arrange
            $testFile = Join-Path $TestDrive "empty-lines.dat"
            $content = @(
                "ID001|John|Doe",
                "",
                "ID002|Jane|Smith",
                "",
                ""
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 2
            $result[0].Values[0] | Should -Be "ID001"
            $result[1].Values[0] | Should -Be "ID002"
        }

        It "Should skip whitespace-only lines" {
            # Arrange
            $testFile = Join-Path $TestDrive "whitespace.dat"
            $content = @(
                "ID001|John|Doe",
                "   ",
                "ID002|Jane|Smith"
            )
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 2
        }
    }

    Context "Empty File Handling" {
        It "Should return empty array for empty file" {
            # Arrange
            $testFile = Join-Path $TestDrive "empty.dat"
            Set-Content -Path $testFile -Value ""

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 0
            $result | Should -BeOfType [System.Array]
        }

        It "Should return empty array for file with only empty lines" {
            # Arrange
            $testFile = Join-Path $TestDrive "only-empty.dat"
            $content = @("", "", "")
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be 0
        }
    }

    Context "Field Count Validation" {
        It "Should throw error on field count mismatch" {
            # Arrange
            $testFile = Join-Path $TestDrive "mismatch.dat"
            $content = "ID001|John|Doe"  # Only 3 fields
            Set-Content -Path $testFile -Value $content

            # Act & Assert
            { Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 5 } | Should -Throw "*Field count mismatch*"
        }

        It "Should throw with specific line number on mismatch" {
            # Arrange
            $testFile = Join-Path $TestDrive "mismatch-line.dat"
            $content = @(
                "ID001|John|Doe|Valid|Record",
                "ID002|Jane|Smith"  # Only 3 fields
            )
            Set-Content -Path $testFile -Value $content

            # Act & Assert
            { Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 5 } | Should -Throw "*line*"
        }

        It "Should throw when multi-line accumulation still insufficient" {
            # Arrange
            $testFile = Join-Path $TestDrive "insufficient.dat"
            $content = @(
                "ID001|Line1",
                "Line2"
                # Still only 2 fields after accumulation, but expected 5
            )
            Set-Content -Path $testFile -Value $content

            # Act & Assert
            { Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 5 } | Should -Throw "*Field count mismatch*"
        }
    }

    Context "Large Files" {
        It "Should handle file with many records" {
            # Arrange
            $testFile = Join-Path $TestDrive "large.dat"
            $recordCount = 1000
            $content = 1..$recordCount | ForEach-Object { "ID$_|Name$_|Value$_" }
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result.Count | Should -Be $recordCount
            $result[0].Values[0] | Should -Be "ID1"
            $result[999].Values[0] | Should -Be "ID1000"
        }
    }

    Context "Special Characters" {
        It "Should preserve special characters in field values" {
            # Arrange
            $testFile = Join-Path $TestDrive "special.dat"
            $content = "ID001|Name with @#$%|Value"
            Set-Content -Path $testFile -Value $content

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result[0].Values[1] | Should -Be "Name with @#$%"
        }

        It "Should handle Unicode characters" {
            # Arrange
            $testFile = Join-Path $TestDrive "unicode.dat"
            $content = "ID001|Café|Résumé"
            Set-Content -Path $testFile -Value $content -Encoding UTF8

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 3

            # Assert
            $result[0].Values[1] | Should -Be "Café"
            $result[0].Values[2] | Should -Be "Résumé"
        }
    }

    Context "Real-world Test Data" {
        It "Should parse TestEmployee.dat fixture" {
            # Arrange
            $testFile = Join-Path $PSScriptRoot "..\..\..\Fixtures\SampleData\TestEmployee.dat"

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 7

            # Assert
            $result.Count | Should -BeGreaterThan 0
            $result[0].Values[0] | Should -Be "EMP001"
            $result[0].Values[1] | Should -Be "John"
        }

        It "Should parse TestDepartment.dat fixture with multi-line" {
            # Arrange
            $testFile = Join-Path $PSScriptRoot "..\..\..\Fixtures\SampleData\TestDepartment.dat"

            # Act
            $result = Read-DatFileLines -FilePath $testFile -ExpectedFieldCount 5

            # Assert
            $result.Count | Should -Be 3
            # Second record spans multiple lines
            $result[1].Values[0] | Should -Be "DEPT002"
            $result[1].Values[3] | Should -Match "multi-line"
        }
    }
}
