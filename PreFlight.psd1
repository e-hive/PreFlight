@{
    # Module manifest for PreFlight

    # Script module or binary module file associated with this manifest.
    RootModule = 'PreFlight.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PowerShell editions
    PowerShellVersion = '7.0'

    # Author of this module
    Author = 'e-hive'

    # Description of the functionality provided by this module
    Description = 'PreFlight PowerShell Module for developer environment validation and prompt enhancement.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellHostVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @(
        'Enable-PreFlightChecks'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
    }
}
