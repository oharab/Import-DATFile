function Initialize-ImportModules {
    <#
    .SYNOPSIS
    Initializes required PowerShell modules for Import-DATFile system.

    .DESCRIPTION
    Checks for and imports SqlServer and ImportExcel modules.
    Provides consistent error messaging if modules are missing.
    Called automatically when SqlServerDataImport module is imported.

    .PARAMETER ThrowOnError
    If specified, throws an exception when modules are missing.
    Otherwise, returns false.

    .EXAMPLE
    Initialize-ImportModules -ThrowOnError

    .EXAMPLE
    if (-not (Initialize-ImportModules)) {
        Write-Host "Please install required modules"
        exit 1
    }
    #>
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )

    $missingModules = @()

    # Check SqlServer module
    try {
        Import-Module SqlServer -ErrorAction Stop
        Write-Verbose "SqlServer module loaded successfully"
    }
    catch {
        $missingModules += "SqlServer"
    }

    # Check ImportExcel module
    try {
        Import-Module ImportExcel -ErrorAction Stop
        Write-Verbose "ImportExcel module loaded successfully"
    }
    catch {
        $missingModules += "ImportExcel"
    }

    if ($missingModules.Count -gt 0) {
        $message = "Required modules not found: $($missingModules -join ', '). Please install using: Install-Module -Name $($missingModules -join ', ')"

        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    return $true
}
