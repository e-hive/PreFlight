<#
.SYNOPSIS
    PreFlight Setup script for deploying the PreFlight PowerShell module and updating the PowerShell profile.

.LINK
    https://github.com/e-hive/PreFlight
#>

# ==========================================
# Deploy PreFlight
# ==========================================

function Deploy-Module {
    param (
        # Module name must match the psm1 & psd1 file names.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        # Optional Scope for module deployment, defaults to "CurrentUser", falls back to "AllUsers" if local modules path isn't registered
        [Parameter(Mandatory = $false)]
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]$Scope 
    )

    try {

        $pwshModulesFolder = ""
        $registeredModulePathStrings = @()

        Write-Host "`nDEPLOY-MODULE: Checking Pwsh Configuration..."

        # Get the contents of PSModulePath
        Write-Host "DEPLOY-MODULE: Checking PSModulePath for valid paths"
        $env:PSModulePath -split ";" | ForEach-Object {
            $modulePath = $_
            if (-not [string]::IsNullOrWhiteSpace($modulePath.Trim())) {
                $registeredModulePathStrings += $modulePath
            }
        }


        # Check for user modules folder
        #----------------------------------------
        If(-not ($Scope) -or $Scope -eq "CurrentUser") {
            Write-Host "DEPLOY-MODULE: Checking for User Module Path"
            
            # Confirm Windows system pointer resolves.
            if($([Environment]::GetFolderPath("MyDocuments")) -eq $null) {
                Write-Host "DEPLOY-MODULE: System MyDocuments pointer is not valid. Please check your environment." -ForegroundColor Red
                exit
            }

            # Gets an absolute path to the expected user modules folder
            $userModulesPath = "$([Environment]::GetFolderPath("MyDocuments"))\PowerShell\Modules"

            # Check if the expected user modules path is included in PSModulePath
            $registeredModulePathStrings | ForEach-Object {
                if ($_.Trim().ToLower() -eq $userModulesPath.Trim().ToLower()) {
                    $pwshModulesFolder = $userModulesPath
                    Write-Host "DEPLOY-MODULE: - User Module Path $userModulesPath found in PSModulePath."
                    return # Exit the loop if we've found a user module path
                }
            }
        }


        # Check for global modules folder
        #----------------------------------------
        If([string]::IsNullOrWhiteSpace($pwshModulesFolder) -and (-not ($Scope) -or $Scope -eq "AllUsers")) {
            Write-Host "DEPLOY-MODULE: Checking for Global Module Path"

            # If no Scope is passed confirm that we haven't already found a user modules path
            if ([string]::IsNullOrWhiteSpace($pwshModulesFolder)) {
                if($env:PROGRAMFILES -eq $null) {
                    Write-Host "DEPLOY-MODULE: System PROGRAMFILES pointer is not valid. Please check your environment." -ForegroundColor Red
                    exit
                }
                # Gets an absolute path to the expected global modules folder
                $globalModulesPath = "$env:PROGRAMFILES\PowerShell\Modules"        
                
                $registeredModulePathStrings | ForEach-Object {
                    if ($_.Trim().ToLower() -eq $globalModulesPath.Trim().ToLower()) {
                        $pwshModulesFolder = $globalModulesPath
                        Write-Host "DEPLOY-MODULE: - Global Module Path $globalModulesPath found in PSModulePath."
                    }
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($pwshModulesFolder)) {
            Write-Host "DEPLOY-MODULE: No matching module paths found in PSModulePath." -ForegroundColor Red
            throw
        }

        # Check to ensure the modules folder exists on disk.
        if (-not (Test-Path "$($pwshModulesFolder)")) {
            Write-Host "DEPLOY-MODULE: - Creating modules folder: $($pwshModulesFolder)"
            try {
                New-Item -ItemType Directory -Path "$($pwshModulesFolder)" -Force | Out-Null
            } catch {
                Write-Host "DEPLOY-MODULE: Failed to create module folder $($pwshModulesFolder)." -ForegroundColor Red
                throw
            }
        }

        # Create the new module folder if it doesn’t exist
        if (-not (Test-Path "$($pwshModulesFolder)\$($ModuleName)")) {
            Write-Host "DEPLOY-MODULE: - Creating $ModuleName folder: $($pwshModulesFolder)\$($ModuleName)"
            try {
            New-Item -ItemType Directory -Path "$($pwshModulesFolder)\$($ModuleName)" -Force | Out-Null
            } catch {
                Write-Host "DEPLOY-MODULE: Failed to create module folder $($pwshModulesFolder)." -ForegroundColor Red
                throw
            }
        }

        # Deploy the module files
        $moduleFolder = "$($pwshModulesFolder)\$($ModuleName)"
        Write-Host "DEPLOY-MODULE: Deploying $ModuleName Module..."
        Write-Host "DEPLOY-MODULE: Module deploy path $moduleFolder"

        $sourceFolder = (Get-Location).Path
        Copy-Item -Path "$($sourceFolder)\$($ModuleName).psm1" -Destination "$moduleFolder\$($ModuleName).psm1" -Force
        Copy-Item -Path "$($sourceFolder)\$($ModuleName).psd1" -Destination "$moduleFolder\$($ModuleName).psd1" -Force

        # Remove the module from the script session if it is already imported
        if (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
            Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
        }

        # Load/Reload the module
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Host "DEPLOY-MODULE: $ModuleName loaded successfully."
        } catch {
            Write-Host "DEPLOY-MODULE: Failed to reload $($ModuleName)." -ForegroundColor Red
            throw
        }
    } catch {
        Write-Host "DEPLOY-MODULE: $ModuleName setup failed" -ForegroundColor Red
        $err = $_
        Write-Host " - Error Message: $($err.Exception.Message)"
        Write-Host " - Error Line Number: $($err.InvocationInfo.ScriptLineNumber)"
        Write-Host " - Error Position: $($err.InvocationInfo.PositionMessage)"
        Write-Host " - Error Script Name: $($err.InvocationInfo.ScriptName)"
        exit
    }
}


# ==========================================
# Update Profile
# ==========================================

function Update-Profile {
    param (
        # The content to append to the profile file
        [Parameter(Mandatory = $true)]
        [string]$Content,

        # A string to check for before appending content to the profile file
        [Parameter(Mandatory = $true)]
        [string]$ContentQuery
    )

    try {
        $pwshProfilePath = 'PowerShell\Microsoft.PowerShell_profile.ps1'

        Write-Host "`nUPDATE-PROFILE: Checking Pwsh PROFILE..."
        Write-Host "UPDATE-PROFILE: $PROFILE"

        if ($PROFILE -notlike "*$pwshProfilePath*") {
            Write-Host "UPDATE-PROFILE: Unexpected PROFILE path. Expected: $pwshProfilePath"
            Write-Host "UPDATE-PROFILE: You may be running an unsupported version of PowerShell Core."
            Write-Host "UPDATE-PROFILE: Exiting setup."
            exit
        }

        # Get an absolute PROFILE path
        if ([System.IO.Path]::IsPathRooted($PROFILE)) {
            $absoluteProfilePath = $PROFILE
        } else {
            $absoluteProfilePath = Join-Path $env:USERPROFILE -ChildPath $pwshProfilePath
        }

        # Create PROFILE if missing
        if (-not (Test-Path -Path $absoluteProfilePath)) {
            Write-Host "UPDATE-PROFILE: Pwsh PROFILE does not exist. Creating..."
            New-Item -Path $absoluteProfilePath -ItemType File -Force | Out-Null
        }

        # Get PROFILE contents
        $profileContent = Get-Content -Path $absoluteProfilePath

        # If our module content isn't already added
        if (-not ($profileContent | Select-String -Pattern $ContentQuery)){
            # Get approval to proceed
            $confirmation = Read-Host "`nUPDATE-PROFILE: Pwsh PROFILE is not empty. Do you want to modify it? (yes/no)"
            if ($confirmation -ne "yes") {
                Write-Host "UPDATE-PROFILE: Exiting setup."
                exit
            }

            if (-not ([string]::IsNullOrWhiteSpace($profileContent))) {
                # Backup current profile if its not empty
                if (Test-Path -Path $absoluteProfilePath) {
                    $timestamp = (Get-Date -Format "yyyyMMddHHmmss")
                    $backupPath = "$absoluteProfilePath.$timestamp.bak"
                    Copy-Item -Path $absoluteProfilePath -Destination $backupPath -Force
                    Write-Host "UPDATE-PROFILE: Backup created: $backupPath"
                }
            }

            # If we get to this point the file can be updated
            Write-Host "`nUPDATE-PROFILE: Modifying PROFILE..."
            Add-Content -Path $absoluteProfilePath -Value $Content
            Write-Host "UPDATE-PROFILE: Updated with Content."
        } else {
            Write-Host "UPDATE-PROFILE: PROFILE Already contains $($ContentQuery). Skipping..."
        }

    } catch {
        Write-Host "UPDATE-PROFILE: Update failed" -ForegroundColor Red
        $err = $_
        Write-Host " - Error Message: $($err.Exception.Message)"
        Write-Host " - Error Line Number: $($err.InvocationInfo.ScriptLineNumber)"
        Write-Host " - Error Position: $($err.InvocationInfo.PositionMessage)"
        Write-Host " - Error Script Name: $($err.InvocationInfo.ScriptName)"
        exit
    }
}

function Assert-RuntimeRequirements {
    # Check if running PowerShell 7+
    if ($Host.Version.Major -lt 7) {
        Write-Host "PREFLIGHT SETUP: This script requires PowerShell 7 or higher." -ForegroundColor Red
        Write-Host "PREFLIGHT SETUP: Current version: $($Host.Version)" -ForegroundColor Red
        Write-Host "PREFLIGHT SETUP: Exiting setup."
        exit
    }

    # Check if script is running in the correct execution context
    if ($PSCmdlet -and $PSCmdlet.MyInvocation.InvocationName -ne ".") {
        Write-Host "PREFLIGHT SETUP: This script must be run in the context of a script file, not dot-sourced or as a function." -ForegroundColor Red
        Write-Host "PREFLIGHT SETUP: Exiting setup."
        exit
    }

    # Check for elevated permissions
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "PREFLIGHT SETUP: This script requires elevated permissions (Run as Administrator)." -ForegroundColor Red
        Write-Host "PREFLIGHT SETUP: Exiting setup."
        exit
    }

    Write-Host "PREFLIGHT SETUP: Environment checks passed. Proceeding with setup..." -ForegroundColor Green
}

# ==========================================
# PreFlight Setup
# ==========================================
Clear-Host
Write-Host @"
================================================
PreFlight Setup
================================================

PreFlight is an Integration test harness for 
your local Pwsh environment

This script will deploy the PreFlight Pwsh 
Module and append PreFlight to your Pwsh PROFILE.

------------------------------------------------
"@ -ForegroundColor DarkCyan


# Confirmation to proceed with setup
$beginSetup = Read-Host "Are you ready to deploy PreFlight? (yes/no)"
if ($beginSetup -ne "yes") {
    Write-Host "PROFILE: Exiting setup."
    exit
}

# Environment checks
Assert-RuntimeRequirements

# Deploy the PreFlight module to the default user modules folder
Deploy-Module -ModuleName "PreFlight"

# Add PreFlight hook to the PowerShell profile
$preflightHook = @(
    "#========================================="
    "# PreFlight Integration"
    "#========================================="
    "if (-not (Get-Module -Name PreFlight -ErrorAction SilentlyContinue)) {"
    "    Import-Module PreFlight -Force"
    "    Enable-PreFlightChecks"
    "}"
) -join "`n"
Update-Profile -Content $preflightHook -ContentQuery "Enable-PreFlightChecks"

# Open a new PowerShell session to reload PROFILE
Write-Host "Opening a new PowerShell session to run preflight tests."
pwsh -NoExit