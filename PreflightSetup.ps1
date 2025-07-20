<#
.SYNOPSIS
    PreFlight Setup Script
#>

#========================================
# Deploy Preflight
#========================================
function Deploy-Module {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName
    )

    try {

        # Locates the users modules directory
        $modulesFolder = Join-Path -Path ([Environment]::GetFolderPath("MyDocuments")) -ChildPath "PowerShell\Modules"
        if (-not $modulesFolder) {
            throw "Cannot locate user modules directory. PSModulePath is misconfigured."
        }

        Write-Host "MODULE: Found User modules folder: $modulesFolder"
        $moduleFolder = Join-Path $modulesFolder $ModuleName

        # Checks for and creates the module folder if it doesn't exist
        if (-not (Test-Path -Path $moduleFolder)) {
            Write-Host "MODULE: Creating $ModuleName folder: $moduleFolder"
            New-Item -ItemType Directory -Path $moduleFolder -Force | Out-Null
        }

        # Installs the latest PreFlight module files
        Write-Host "MODULE: Installing $ModuleName files..."
        $sourceDir = (Get-Location).Path
        Copy-Item -Path "$sourceDir\$($ModuleName).psm1" -Destination "$moduleFolder\$($ModuleName).psm1" -Force
        Copy-Item -Path "$sourceDir\$($ModuleName).psd1" -Destination "$moduleFolder\$($ModuleName).psd1" -Force

        # Remove the module from the current context if its already imported
        if (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue) {
            Write-Host "MODULE: $ModuleName already installed."
            Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
            Write-Host "MODULE: $ModuleName removed from current session."
        }

        # Load the module to ensure the latest version is visible to Pwsh
        try {
            Import-Module -Name $ModuleName -Force -ErrorAction Stop
            Write-Host "MODULE: $ModuleName loaded successfully."
        } catch {
            Write-Host "MODULE: Failed to reload $($ModuleName): $_" -ForegroundColor Red
            throw
        }
    } catch {
        Write-Host "MODULE: $ModuleName setup failed: $_" -ForegroundColor Red
        exit
    }
}

#========================================
# Update Profile
#========================================
function Update-Profile{
    try {
        $pwshProfilePath = 'PowerShell\Microsoft.PowerShell_profile.ps1'
        $scriptPath = Join-Path $env:USERPROFILE ".preflight\PreFlight.ps1"

        Write-Host "PROFILE path: $PROFILE"
        if ($PROFILE -notlike "*$pwshProfilePath*") {
            Write-Host "Unexpected PROFILE path. Expected: $pwshProfilePath"
            Write-Host "Exiting setup."
            exit
        }

        # Ensure an absolute profile path
        if ([System.IO.Path]::IsPathRooted($PROFILE)) {
            $absoluteProfilePath = $PROFILE
        } else {
            $absoluteProfilePath = Join-Path $env:USERPROFILE -ChildPath $pwshProfilePath
        }

        # Create profile if it doesn't exist
        if (-not (Test-Path -Path $absoluteProfilePath)) {
            Write-Host "PROFILE does not exist. Creating..."
            New-Item -Path $absoluteProfilePath -ItemType File -Force | Out-Null
        }

        $profileContent = Get-Content -Path $absoluteProfilePath
        if (-not $profileContent -or -not ($profileContent | Select-String -Pattern "PreFlight Integration")) {
            # Challenges before modifying the profile
            $confirmation = Read-Host "PROFILE is not empty. Do you want to modify it? (yes/no)"
            if ($confirmation -ne "yes") {
                Write-Host "Exiting setup."
                exit
            }

            # Backs up the profile if it exists
            if (Test-Path -Path $absoluteProfilePath) {
                $timestamp = (Get-Date -Format "yyyyMMddHHmmss")
                $backupPath = "$absoluteProfilePath.$timestamp.bak"
                Copy-Item -Path $absoluteProfilePath -Destination $backupPath -Force
                Write-Host "PROFILE backup created: $backupPath"
            }

            # Prepare the PreFlight integration using module loading
            $preflightLogic = @(
                "# PreFlight Integration",
                "if (-not (Get-Module -Name PreFlight -ErrorAction SilentlyContinue)) {",
                "    Import-Module PreFlight -Force",
                "    Enable-PreFlightChecks",
                "}"
            ) -join "`n"

            # Adds PreFlight to the profile
            Add-Content -Path $absoluteProfilePath -Value $preflightLogic
            Write-Host "PROFILE updated with PreFlight."
        } else {
            Write-Host "PROFILE already contains PreFlight."
        }

    } catch {
        Write-Host "PROFILE update failed: $_" -ForegroundColor Red
        exit
    }
}

Deploy-Module -ModuleName "PreFlight"
Update-Profile

Write-Host "Opening a new PowerShell session to run preflight tests." -ForegroundColor Cyan
& pwsh -NoExit