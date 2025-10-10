# SqlServerDataImport PowerShell Module (Modular Structure)
# Root module loader - dot-sources all Private and Public functions
# Refactored to follow PowerShell best practices with Private/Public separation

#region Module Dependencies

# Get module directory
$moduleRoot = $PSScriptRoot

# Load constants
$constantsPath = Join-Path $moduleRoot "Common\Import-DATFile.Constants.ps1"
if (Test-Path $constantsPath) {
    . $constantsPath
}
else {
    throw "Constants file not found at: $constantsPath"
}

# Load type mappings
$typeMappingsPath = Join-Path $moduleRoot "Common\TypeMappings.psd1"
if (Test-Path $typeMappingsPath) {
    $script:TypeMappings = Import-PowerShellDataFile -Path $typeMappingsPath
}
else {
    throw "TypeMappings.psd1 not found at: $typeMappingsPath"
}

# Import common utilities module
$commonModulePath = Join-Path $moduleRoot "Import-DATFile.Common.psm1"
if (Test-Path $commonModulePath) {
    Import-Module $commonModulePath -Force
}
else {
    throw "Common module not found at: $commonModulePath"
}

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
