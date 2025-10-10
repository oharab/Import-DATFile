@{
    # Script module or binary module file associated with this manifest
    RootModule = 'SqlServerDataImport.psm1'

    # Version number of this module
    ModuleVersion = '2.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'bpo'

    # Company or vendor of this module
    CompanyName = 'Unknown'

    # Copyright statement for this module
    Copyright = '(c) 2025 bpo. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'High-performance SQL Server data import module for pipe-separated DAT files with Excel specification support. Refactored with modular Private/Public structure following PowerShell best practices.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ModuleName='SqlServer'; ModuleVersion='21.0.0'; Guid='00000000-0000-0000-0000-000000000000'; RequiredVersion=$null}
        @{ModuleName='ImportExcel'; ModuleVersion='7.0.0'; Guid='00000000-0000-0000-0000-000000000000'; RequiredVersion=$null}
    )

    # Functions to export from this module - ONLY public functions
    FunctionsToExport = @('Invoke-SqlServerDataImport')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for module discovery
            Tags = @('SQL', 'SQLServer', 'DataImport', 'BulkCopy', 'Excel', 'DAT', 'ETL')

            # Release notes of this module
            ReleaseNotes = @'
Version 2.0.0 - Major Refactoring
- Restructured into modular Private/Public folder organization
- Applied DRY and SOLID principles throughout
- Improved maintainability and testability
- Centralized configuration in TypeMappings.psd1
- Enhanced parameter validation
- Better separation of concerns with focused, single-responsibility functions
'@
        }
    }
}
