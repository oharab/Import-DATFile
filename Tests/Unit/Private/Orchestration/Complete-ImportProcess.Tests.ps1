# Complete-ImportProcess.Tests.ps1
# Unit tests for Complete-ImportProcess function

# Import module at script scope (required for InModuleScope)
$moduleRoot = Join-Path $PSScriptRoot "..\..\..\.."
$modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"
Import-Module $modulePath -Force

InModuleScope SqlServerDataImport {
    Describe "Complete-ImportProcess" {

    Context "Summary Display" {
        BeforeEach {
            # Mock dependencies
            Mock Show-ImportSummary { } -ModuleName SqlServerDataImport
            Mock Invoke-PostInstallScripts { } -ModuleName SqlServerDataImport
        }

        It "Should display import summary" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            Complete-ImportProcess -SchemaName "dbo" `
                                   -ConnectionString $connString `
                                   -DatabaseName "TestDB"

            # Assert
            Should -Invoke Show-ImportSummary -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $SchemaName -eq "dbo"
            }
        }

        It "Should not invoke post-install scripts when not specified" {
            # Arrange
            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            Complete-ImportProcess -SchemaName "dbo" `
                                   -ConnectionString $connString `
                                   -DatabaseName "TestDB"

            # Assert
            Should -Invoke Invoke-PostInstallScripts -Times 0 -ModuleName SqlServerDataImport
        }
    }

    Context "Post-Install Scripts" {
        BeforeEach {
            Mock Show-ImportSummary { } -ModuleName SqlServerDataImport
        }

        It "Should invoke post-install scripts when specified" {
            # Arrange
            Mock Invoke-PostInstallScripts { } -ModuleName SqlServerDataImport

            $scriptPath = Join-Path $TestDrive "PostInstall.sql"
            "SELECT 1" | Set-Content $scriptPath

            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            Complete-ImportProcess -SchemaName "dbo" `
                                   -ConnectionString $connString `
                                   -DatabaseName "TestDB" `
                                   -PostInstallScripts $scriptPath

            # Assert
            Should -Invoke Invoke-PostInstallScripts -Times 1 -ModuleName SqlServerDataImport -ParameterFilter {
                $ScriptPath -eq $scriptPath -and
                $DatabaseName -eq "TestDB" -and
                $SchemaName -eq "dbo"
            }
        }

        It "Should not throw when post-install scripts fail" {
            # Arrange
            Mock Invoke-PostInstallScripts { throw "Script failed" } -ModuleName SqlServerDataImport

            $scriptPath = Join-Path $TestDrive "PostInstall.sql"
            "SELECT 1" | Set-Content $scriptPath

            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act & Assert - Should not throw
            { Complete-ImportProcess -SchemaName "dbo" `
                                     -ConnectionString $connString `
                                     -DatabaseName "TestDB" `
                                     -PostInstallScripts $scriptPath `
                                     -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should skip empty or whitespace post-install script paths" {
            # Arrange
            Mock Invoke-PostInstallScripts { } -ModuleName SqlServerDataImport

            $connString = "Server=localhost;Database=TestDB;Integrated Security=True;"

            # Act
            Complete-ImportProcess -SchemaName "dbo" `
                                   -ConnectionString $connString `
                                   -DatabaseName "TestDB" `
                                   -PostInstallScripts "   "

            # Assert
            Should -Invoke Invoke-PostInstallScripts -Times 0 -ModuleName SqlServerDataImport
        }
    }
    }
}
