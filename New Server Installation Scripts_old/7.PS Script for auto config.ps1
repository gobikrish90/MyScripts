# Prompt for JSON file path
$JsonPath = Read-Host "Enter the path to the app configuration JSON file"
if (-not $JsonPath) {
    $JsonPath = ".\appConfigSettings.json"
    Write-Host "No input provided. Defaulting to: $JsonPath"
    Start-Sleep -Seconds 1
}

# Prompt for SSRS Report Server credentials (without password)
$ssrsUser = Read-Host "Enter SSRS Report Server Username"
$ssrsPass = ""  # password intentionally left blank
$ssrsDomain = Read-Host "Enter SSRS Domain"

# Prompt for certificate name (used in selective keys)
$certName = Read-Host "Enter Certificate Name"
Write-Host "Certificate to be used: $certName"
Start-Sleep -Seconds 1

# Get dynamic environment info
$hostname = $env:COMPUTERNAME
$fullHostname = [System.Net.Dns]::GetHostByName($hostname).HostName

# Get local IPv4 address (excluding loopbacks)
$ipAddress = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object {
    $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -notlike '127.*'
} | Select-Object -First 1

# Display system info
Write-Host "`n==== Environment Info ====" -ForegroundColor Cyan
Write-Host "Hostname       : $hostname"
Write-Host "Full Hostname  : $fullHostname"
Write-Host "IP Address     : $($ipAddress.IPAddressToString)"
Write-Host "===========================" -ForegroundColor Cyan
Start-Sleep -Seconds 2

# Detect ProPhoenix base paths across all drives
$ppBasePaths = Get-PSDrive -PSProvider 'FileSystem' | ForEach-Object {
    $rootPath = Join-Path $_.Root "Program Files\ProPhoenix"
    if (Test-Path $rootPath) { $rootPath }
}

if (-not $ppBasePaths) {
    Write-Error "ProPhoenix base path not found on any drive!"
    exit 1
}

Write-Host "Detected base ProPhoenix paths on drives:" -ForegroundColor Cyan
$ppBasePaths | ForEach-Object { Write-Host "  $_" }
Start-Sleep -Seconds 2

# Load configuration JSON
if (-Not (Test-Path $JsonPath)) {
    Write-Error "JSON configuration file not found at: $JsonPath"
    exit 1
}
$appConfigs = Get-Content $JsonPath | ConvertFrom-Json
Start-Sleep -Seconds 1

# Global replacements
$replacements = @{
    'hostname'      = $hostname
    'fullhostname'  = $fullHostname
    'full_hostname' = $fullHostname
    'cert_name'     = $certName
    'ssrs_user'     = $ssrsUser       
    'ssrs_domain'   = $ssrsDomain     
}

# Keys where cert_name should be replaced
$keysToUseCertName = @("KPIRMSURL", "KPIFireRMSURL", "PnxPdfService")

# Function to update or add key
function UpdateOrAddKey([xml]$xmlDoc, $settingsNode, $key, $value, $subInstance) {
    $replacements['sub_instance'] = $subInstance
    $finalValue = $value

    foreach ($placeholder in $replacements.Keys) {
        if (($key -in $keysToUseCertName -and $placeholder -eq 'cert_name') -or
            ($key -notin $keysToUseCertName -and $placeholder -ne 'cert_name')) {
            $finalValue = $finalValue -replace "(?i)\{$placeholder\}", $replacements[$placeholder]
        }
    }

    $node = $settingsNode.add | Where-Object { $_.key -eq $key }
    if ($node) {
        $node.value = $finalValue
    } else {
        $newElem = $xmlDoc.CreateElement("add")
        $newElem.SetAttribute("key", $key)
        $newElem.SetAttribute("value", $finalValue)
        $settingsNode.AppendChild($newElem) | Out-Null
    }
}

# Loop through apps
foreach ($app in $appConfigs) {
    Write-Host "`nProcessing: $($app.AppName)" -ForegroundColor Cyan
    Start-Sleep -Seconds 1

    $matchedFiles = @()

    foreach ($basePath in $ppBasePaths) {
        $searchPattern = Join-Path $basePath ($app.RelativePath -replace '\\', [IO.Path]::DirectorySeparatorChar)
        $found = Get-ChildItem -Path $searchPattern -File -ErrorAction SilentlyContinue
        if ($found) {
            $matchedFiles += $found
        }
    }

    if (-not $matchedFiles) {
        Write-Warning "No matching files found for any base path for: $($app.RelativePath)"
        Start-Sleep -Seconds 1
        continue
    }

    foreach ($configFile in $matchedFiles) {
        $subInstance = $configFile.Directory.Name
        $replacements['sub_instance'] = $subInstance
        $replacements['drive'] = ($configFile.Directory.Root.FullName).TrimEnd('\')
        $replacements['reportserverpath'] = Join-Path $replacements['drive'] "Program Files\ProPhoenix\Report Server"

        Write-Host "Updating config file: $($configFile.FullName)" -ForegroundColor Yellow
        Start-Sleep -Seconds 1

        [xml]$xml = Get-Content $configFile.FullName

        if (-not $xml.configuration.appSettings) {
            $appSettings = $xml.CreateElement("appSettings")
            $xml.configuration.AppendChild($appSettings) | Out-Null
        } else {
            $appSettings = $xml.configuration.appSettings
        }

        foreach ($kv in $app.Settings.PSObject.Properties) {
            if ($kv.Name -match 'Path$') {
                $resolvedPath = $kv.Value
                foreach ($p in @('drive', 'sub_instance')) {
                    $resolvedPath = $resolvedPath -replace "(?i)\{$p\}", $replacements[$p]
                }
                if (-not (Test-Path $resolvedPath)) {
                    New-Item -Path $resolvedPath -ItemType Directory -Force | Out-Null
                    Write-Host "Created missing path: $resolvedPath"
                    Start-Sleep -Seconds 1
                }
            }

            UpdateOrAddKey $xml $appSettings $kv.Name $kv.Value $subInstance
            Write-Host "  -> Updated key: $($kv.Name)" -ForegroundColor DarkGray
            Start-Sleep -Seconds 1
        }

        $xml.Save($configFile.FullName)
        Write-Host "✔ Updated successfully: $($configFile.FullName)" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }
} # ← Properly closed foreach ($app in $appConfigs)

# Handle Report Server (web.config) separately
$reportWebConfig = $null
foreach ($basePath in $ppBasePaths) {
    $candidate = Join-Path $basePath "Report Server\web.config"
    if (Test-Path $candidate) {
        $reportWebConfig = $candidate
        break
    }
}
