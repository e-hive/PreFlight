<#
.SYNOPSIS
    PreFlight PowerShell Module for developer environment validation

.LINK
    https://github.com/e-hive/PreFlight
#>

# Global variable to track if PreFlight has already run the environment checks
$script:__PreFlight_ChecksCompleted = $false

#========================================
# Test Functions
#========================================
# Function to check if the session is running in admin mode
function Test-AdminMode {
    if (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Host "[PreFlight] Warning: PowerShell is not running in Admin mode." -ForegroundColor Yellow
    }
}

# Function to check the PowerShell version
function Test-PowerShellVersion {
    $minimumVersion = [Version]"7.5"
    if ([Version]$Host.Version -lt $minimumVersion) {
        Write-Host "[PreFlight] Warning: PowerShell version is below $($minimumVersion)." -ForegroundColor Yellow
    }
}

# Function to check the execution policy
function Test-ExecutionPolicy {
    $requiredPolicy = "RemoteSigned"
    if ((Get-ExecutionPolicy) -ne $requiredPolicy) {
        Write-Host "[PreFlight] Warning: Execution policy is not set to $requiredPolicy." -ForegroundColor Yellow
    }
}

# Function to check installed modules
function Test-InstalledModules {
    $requiredModules = @(
        @{ Name = "Az"; MinimumVersion = "5.0.0" },
        @{ Name = "SqlServer"; MinimumVersion = "22.0.0" }
    )

    foreach ($module in $requiredModules) {
        $installedModule = Get-Module -ListAvailable -Name $module.Name | Where-Object { $_.Version -ge [Version]$module.MinimumVersion }
        if (-not $installedModule) {
            Write-Host "[PreFlight] Warning: Module $($module.Name) version $($module.MinimumVersion) or higher is not installed." -ForegroundColor Yellow
        }
    }
}

# Function to check installed tools
function Test-InstalledTools {

    $tools = @(
        @{ Name = "git"; Command = "[regex]::Match((git --version), '\d+\.\d+\.\d+').Value"; MinVersion = "2.0" },
        @{ Name = "dotnet"; Command = "dotnet --version"; MinVersion = "7.0" },
        @{ Name = "node"; Command = "node --version"; MinVersion = "16.0" },
        @{ Name = "az"; Command = "az version | ConvertFrom-Json | Select-Object -ExpandProperty azure-cli"; MinVersion = "2.0" },
        @{ Name = "kubectl"; Command = "(kubectl version --client --output json | ConvertFrom-Json).clientVersion.gitVersion.TrimStart('v')"; MinVersion = "1.20" },
        @{ Name = "docker"; Command = "docker --version"; MinVersion = "20.10" },
        @{ Name = "preflighttest"; Command = "preflighttest --version"; MinVersion = "999" }
        #@{ Name = "terraform"; Command = "terraform --version"; MinVersion = "1.0" },
        #@{ Name = "helm"; Command = "helm version --short --client | ForEach-Object { $_ -replace 'v', '' }"; MinVersion = "3.0" },
        #@{ Name = "npm"; Command = "npm --version"; MinVersion = "8.0" },
        #@{ Name = "yarn"; Command = "yarn --version"; MinVersion = "1.22" },
        #@{ Name = "azcopy"; Command = "[regex]::Match((azcopy --version), '\d+\.\d+\.\d+').Value"; MinVersion = "10.0" }
    )

    foreach ($tool in $tools) {
        $cmd = Get-Command $tool.Name -ErrorAction SilentlyContinue
        if (-not $cmd) {
            Write-Host "[PreFlight] Warning: $($tool.Name) is not installed or not in PATH." -ForegroundColor Yellow
            continue
        }

        try {
            $output = Invoke-Expression $tool.Command 2>&1
            if (-not $output) {
                Write-Host "[PreFlight] Error: No version output from $($tool.Name)" -ForegroundColor Red
            }

            $versionString = $output -replace '[^\d.]', ''
            $version = [version]$versionString

            if ($version -lt [version]$tool.MinVersion) {
                Write-Host "[PreFlight] Warning: $($tool.Name) version $version is below required $($tool.MinVersion)" -ForegroundColor Yellow
            }

            #Write-Host "$($tool.Name) version $version OK" -ForegroundColor Green
        } catch {
            Write-Host "[PreFlight] Error: Failed to retrieve version for $($tool.Name)" -ForegroundColor Red
        }
    }
}

#========================================
# Test Orchestration
#========================================
function Test-Environment {
    if (-not $script:__PreFlight_ChecksCompleted) {
        # Comment/Uncomment as needed
        Test-AdminMode
        Test-PowerShellVersion
        Test-ExecutionPolicy
        Test-InstalledModules
        Test-InstalledTools
        Write-Host ""
        $script:__PreFlight_ChecksCompleted = $true
    }
}


function Enable-PreFlightChecks {
    Test-Environment
}

Export-ModuleMember -Function Enable-PreFlightChecks