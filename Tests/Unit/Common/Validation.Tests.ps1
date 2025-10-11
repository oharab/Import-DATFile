# Validation.Tests.ps1
# Characterization tests for validation functions
# Tests Test-SchemaName and Test-ImportPath

BeforeAll {
    # Get module root
    $moduleRoot = Join-Path $PSScriptRoot "..\..\.."

    # Dot-source Private validation functions needed for testing
    . (Join-Path $moduleRoot "Private\Validation\Test-ImportPath.ps1")
    . (Join-Path $moduleRoot "Private\Validation\Test-SchemaName.ps1")
}

Describe "Test-SchemaName" {

    Context "Valid Schema Names" {
        It "Should accept simple schema name" {
            $result = Test-SchemaName -SchemaName "dbo"
            $result | Should -Be $true
        }

        It "Should accept schema name with underscores" {
            $result = Test-SchemaName -SchemaName "my_schema"
            $result | Should -Be $true
        }

        It "Should accept schema name with numbers" {
            $result = Test-SchemaName -SchemaName "schema123"
            $result | Should -Be $true
        }

        It "Should accept mixed alphanumeric with underscores" {
            $result = Test-SchemaName -SchemaName "my_schema_2024"
            $result | Should -Be $true
        }

        It "Should accept uppercase schema names" {
            $result = Test-SchemaName -SchemaName "PRODUCTION"
            $result | Should -Be $true
        }

        It "Should accept mixed case schema names" {
            $result = Test-SchemaName -SchemaName "MySchema"
            $result | Should -Be $true
        }

        It "Should accept schema name starting with number" {
            $result = Test-SchemaName -SchemaName "2024_schema"
            $result | Should -Be $true
        }

        It "Should accept single character schema name" {
            $result = Test-SchemaName -SchemaName "s"
            $result | Should -Be $true
        }
    }

    Context "Invalid Schema Names" {
        It "Should reject schema name with semicolon (SQL injection)" {
            $result = Test-SchemaName -SchemaName "schema;DROP TABLE"
            $result | Should -Be $false
        }

        It "Should reject schema name with dash" {
            $result = Test-SchemaName -SchemaName "my-schema"
            $result | Should -Be $false
        }

        It "Should reject schema name with space" {
            $result = Test-SchemaName -SchemaName "my schema"
            $result | Should -Be $false
        }

        It "Should reject schema name with special characters" {
            $result = Test-SchemaName -SchemaName "schema@example"
            $result | Should -Be $false
        }

        It "Should reject schema name with parentheses" {
            $result = Test-SchemaName -SchemaName "schema(test)"
            $result | Should -Be $false
        }

        It "Should reject schema name with brackets" {
            $result = Test-SchemaName -SchemaName "schema[test]"
            $result | Should -Be $false
        }

        It "Should reject schema name with quotes" {
            $result = Test-SchemaName -SchemaName "schema'test"
            $result | Should -Be $false
        }

        It "Should reject schema name with double quotes" {
            $result = Test-SchemaName -SchemaName 'schema"test'
            $result | Should -Be $false
        }

        It "Should reject schema name with slash" {
            $result = Test-SchemaName -SchemaName "schema/test"
            $result | Should -Be $false
        }

        It "Should reject schema name with backslash" {
            $result = Test-SchemaName -SchemaName "schema\test"
            $result | Should -Be $false
        }
    }

    Context "ThrowOnError Parameter" {
        It "Should throw exception when invalid and ThrowOnError specified" {
            { Test-SchemaName -SchemaName "invalid;schema" -ThrowOnError } | Should -Throw
        }

        It "Should throw with meaningful error message" {
            { Test-SchemaName -SchemaName "invalid schema" -ThrowOnError } | Should -Throw "*Invalid schema name*"
        }

        It "Should not throw when valid and ThrowOnError specified" {
            { Test-SchemaName -SchemaName "valid_schema" -ThrowOnError } | Should -Not -Throw
        }
    }

    Context "Edge Cases" {
        It "Should reject empty schema name with parameter validation" {
            # Function has ValidateNotNullOrEmpty, so it throws ParameterBindingValidationException
            { Test-SchemaName -SchemaName "" } | Should -Throw "*empty string*"
        }

        It "Should reject null schema name with parameter validation" {
            # Function has ValidateNotNullOrEmpty, so it throws ParameterBindingValidationException
            { Test-SchemaName -SchemaName $null } | Should -Throw "*empty string*"
        }
    }
}

Describe "Test-ImportPath" {

    Context "File Path Validation" {
        It "Should return true for existing file" {
            # Arrange
            $testFile = Join-Path $TestDrive "testfile.txt"
            Set-Content -Path $testFile -Value "test"

            # Act
            $result = Test-ImportPath -Path $testFile -PathType File

            # Assert
            $result | Should -Be $true
        }

        It "Should return false for non-existing file" {
            # Arrange
            $nonExistentFile = Join-Path $TestDrive "nonexistent.txt"

            # Act
            $result = Test-ImportPath -Path $nonExistentFile -PathType File -ErrorAction SilentlyContinue

            # Assert
            $result | Should -Be $false
        }

        It "Should return false when path is directory but expecting file" {
            # Act
            $result = Test-ImportPath -Path $TestDrive -PathType File -ErrorAction SilentlyContinue

            # Assert
            $result | Should -Be $false
        }
    }

    Context "Folder Path Validation" {
        It "Should return true for existing folder" {
            # Act
            $result = Test-ImportPath -Path $TestDrive -PathType Folder

            # Assert
            $result | Should -Be $true
        }

        It "Should return false for non-existing folder" {
            # Arrange
            $nonExistentFolder = Join-Path $TestDrive "nonexistent_folder"

            # Act
            $result = Test-ImportPath -Path $nonExistentFolder -PathType Folder -ErrorAction SilentlyContinue

            # Assert
            $result | Should -Be $false
        }

        It "Should return false when path is file but expecting folder" {
            # Arrange
            $testFile = Join-Path $TestDrive "testfile.txt"
            Set-Content -Path $testFile -Value "test"

            # Act
            $result = Test-ImportPath -Path $testFile -PathType Folder -ErrorAction SilentlyContinue

            # Assert
            $result | Should -Be $false
        }
    }

    Context "ThrowOnError Parameter" {
        It "Should throw exception when file not found and ThrowOnError specified" {
            # Arrange
            $nonExistentFile = Join-Path $TestDrive "nonexistent.txt"

            # Act & Assert
            { Test-ImportPath -Path $nonExistentFile -PathType File -ThrowOnError } | Should -Throw
        }

        It "Should throw with meaningful error message for missing file" {
            # Arrange
            $nonExistentFile = Join-Path $TestDrive "nonexistent.txt"

            # Act & Assert
            { Test-ImportPath -Path $nonExistentFile -PathType File -ThrowOnError } | Should -Throw "*File not found*"
        }

        It "Should throw with meaningful error message for missing folder" {
            # Arrange
            $nonExistentFolder = Join-Path $TestDrive "nonexistent_folder"

            # Act & Assert
            { Test-ImportPath -Path $nonExistentFolder -PathType Folder -ThrowOnError } | Should -Throw "*Folder not found*"
        }

        It "Should not throw when path exists and ThrowOnError specified" {
            # Act & Assert
            { Test-ImportPath -Path $TestDrive -PathType Folder -ThrowOnError } | Should -Not -Throw
        }
    }

    Context "Real-world Fixtures" {
        It "Should validate TestEmployee.dat fixture file" {
            # Arrange
            $fixtureFile = Join-Path $PSScriptRoot "..\..\Fixtures\SampleData\TestEmployee.dat"
            $fixtureFile = [System.IO.Path]::GetFullPath($fixtureFile)

            # Act
            $result = Test-ImportPath -Path $fixtureFile -PathType File

            # Assert
            $result | Should -Be $true
        }

        It "Should validate Fixtures folder" {
            # Arrange
            $fixturesFolder = Join-Path $PSScriptRoot "..\..\Fixtures"
            $fixturesFolder = [System.IO.Path]::GetFullPath($fixturesFolder)

            # Act
            $result = Test-ImportPath -Path $fixturesFolder -PathType Folder

            # Assert
            $result | Should -Be $true
        }
    }
}
