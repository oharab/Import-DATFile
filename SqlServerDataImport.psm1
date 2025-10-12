# SqlServerDataImport PowerShell Module (Modular Structure)
# Root module loader - dot-sources all Private and Public functions
# Refactored to follow PowerShell best practices with Private/Public separation

#region Module Setup

# Get module directory
$moduleRoot = $PSScriptRoot

#endregion

#region Global Variables

$script:ImportSummary = @()
$script:VerboseLogging = $false

#endregion

#region Dot-Source Functions

# Dot-source all Private functions
Write-Verbose "Loading Private functions from: $moduleRoot\Private"

$privateFunctions = @(
    Get-ChildItem -Path "$moduleRoot\Private\*.ps1" -Recurse -ErrorAction SilentlyContinue
)

foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded: $($function.Name)"
    }
    catch {
        Write-Error "Failed to load function $($function.FullName): $_"
    }
}

Write-Verbose "Loaded $($privateFunctions.Count) private functions"

# Initialize external module dependencies (SqlServer, ImportExcel)
# This must be called AFTER all Private functions are loaded
Write-Verbose "Initializing external module dependencies..."

if (Get-Command -Name Initialize-ImportModules -ErrorAction SilentlyContinue) {
    Initialize-ImportModules -ThrowOnError
}
else {
    throw "Critical error: Initialize-ImportModules function not loaded. Module cannot initialize external dependencies (SqlServer, ImportExcel)."
}

# Dot-source all Public functions
Write-Verbose "Loading Public functions from: $moduleRoot\Public"

$publicFunctions = @(
    Get-ChildItem -Path "$moduleRoot\Public\*.ps1" -ErrorAction SilentlyContinue
)

foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded: $($function.Name)"
    }
    catch {
        Write-Error "Failed to load function $($function.FullName): $_"
    }
}

Write-Verbose "Loaded $($publicFunctions.Count) public functions"

#endregion

#region Module Exports

# Export only public functions
$publicFunctionNames = $publicFunctions | ForEach-Object {
    $_.BaseName
}

Export-ModuleMember -Function $publicFunctionNames

Write-Verbose "Exported functions: $($publicFunctionNames -join ', ')"

#endregion
