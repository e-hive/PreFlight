<#
.SYNOPSIS
    PreFlight PowerShell Module for developer environment validation

.LINK
    https://github.com/e-hive/PreFlight
#>

# Global variable to track if PreFlight has already run environment checks
$script:__PreFlight_ChecksCompleted = $false

# Set to $true to enable timing output
$script:__showTimers = $false 

#========================================
# Test Functions
#========================================
# Function to check if the session is running in admin mode
function Test-AdminMode {
    $startTime = Get-Date
    if (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Host "[PreFlight] Warning: PowerShell is not running in Admin mode." -ForegroundColor Yellow
    }
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-AdminMode completed in $($endTime - $startTime).TotalMilliseconds ms." }

}

# Function to check the PowerShell version
function Test-PowerShellVersion {
    $startTime = Get-Date
    $minimumVersion = [Version]"7.5"
    if ([Version]$Host.Version -lt $minimumVersion) {
        Write-Host "[PreFlight] Warning: PowerShell version is below $($minimumVersion)." -ForegroundColor Yellow
    }
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-PowerShellVersion completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check the execution policy
function Test-ExecutionPolicy {
    $startTime = Get-Date
    $requiredPolicy = "RemoteSigned"
    if ((Get-ExecutionPolicy) -ne $requiredPolicy) {
        Write-Host "[PreFlight] Warning: Execution policy is not set to $requiredPolicy." -ForegroundColor Yellow
    }
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-ExecutionPolicy completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check installed modules
function Test-InstalledModules {
    $startTime = Get-Date
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
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-InstalledModules completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check installed tools
function Test-InstalledTools {
    $startTime = Get-Date
    $tools = @(
        @{ Name = "git"; Command = "[regex]::Match((git --version), '\d+\.\d+\.\d+').Value"; MinVersion = "2.0" },
        @{ Name = "dotnet"; Command = "dotnet --version"; MinVersion = "7.0" },
        @{ Name = "node"; Command = "node --version"; MinVersion = "16.0" },
        @{ Name = "az"; Command = "az version | ConvertFrom-Json | Select-Object -ExpandProperty azure-cli"; MinVersion = "2.0" },
        @{ Name = "kubectl"; Command = "(kubectl version --client --output json | ConvertFrom-Json).clientVersion.gitVersion.TrimStart('v')"; MinVersion = "1.20" },
        @{ Name = "docker"; Command = "docker --version"; MinVersion = "20.10" }#,
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
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-InstalledTools completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check environment variables
function Test-EnvironmentVariables {
    $startTime = Get-Date
    $requiredEnvironmentVariables = @(
        "http_proxy",
        "https_proxy",
        "no_proxy"
    )

    $envVars = Get-ChildItem Env: | ForEach-Object { $_.Name }
    foreach($requiredEnvironmentVariable in $requiredEnvironmentVariables) {
        if ($envVars -notcontains $requiredEnvironmentVariable) {
            Write-Host "[PreFlight] Warning: Environment variable '$requiredEnvironmentVariable' is not set." -ForegroundColor Yellow
        }
    }

    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-EnvironmentVariables completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check public IP
# Can be useful to warn if a VPN has disconnected etc.
function Test-PublicIP {
    $startTime = Get-Date
    $expectedPublicIP = "44.33.22.11" # Example expected IP, adjust as needed

    try {
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org?format=text"
        if($expectedPublicIP -ne $publicIP){
            Write-Host "[PreFlight] Warning: Public IP Address $publicIP does not match expected $expectedPublicIP." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[PreFlight] Error: Failed to retrieve public IP address." -ForegroundColor Red
    }
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-PublicIP completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

# Function to check service connectivity
# Can be useful to warn when a critical internal service becomes blocked or unreachable.
function Test-ServiceAvailability {
    $startTime = Get-Date
    $ServiceUrls = @(
        @{ Url = "http://www.google.com"; ExpectedStatusCode = 200 },
        @{ Url = "http://cms.lvgig.co.uk"; ExpectedStatusCode = 403 }
    )

    foreach ($service in $ServiceUrls) {
        $url = $service.Url
        $expectedStatusCode = $service.ExpectedStatusCode

        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            if ($response.StatusCode -ne $expectedStatusCode) {
                Write-Host "[PreFlight] Warning: Service at $url returned status code $($response.StatusCode), expected $expectedStatusCode." -ForegroundColor Yellow
            }
        } catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                Write-Host "[PreFlight] Warning: Service at $url returned status code $($_.Exception.Response.StatusCode), expected $expectedStatusCode." -ForegroundColor Yellow
            } else {
                Write-Host "[PreFlight] Error: Failed to connect to service at $url. Exception: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    $endTime = Get-Date
    if($script:__showTimers) { Write-Host "[PreFlight] Test-ServiceAvailability completed in $($endTime - $startTime).TotalMilliseconds ms." }
}

#========================================
# Test Orchestration
#========================================
function Test-Environment {
    if (-not $script:__PreFlight_ChecksCompleted) {
        # Comment/Uncomment tests as needed
        Write-Host ""
        Test-AdminMode
        Test-PowerShellVersion
        Test-ExecutionPolicy
        #Test-InstalledModules
        #Test-InstalledTools
        #Test-EnvironmentVariables
        #Test-PublicIP
        #Test-ServiceAvailability
        Write-Host ""
        $script:__PreFlight_ChecksCompleted = $true
    }
}


function Enable-PreFlightChecks {
    Test-Environment
}

Export-ModuleMember -Function Enable-PreFlightChecks