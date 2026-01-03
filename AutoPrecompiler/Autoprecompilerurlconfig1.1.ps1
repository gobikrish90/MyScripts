# =============================================================================
# STEP 1: DISCOVER IIS ENVIRONMENTS
# =============================================================================
Write-Host "Step 1: Discovering IIS Bindings..." -ForegroundColor Cyan

Import-Module WebAdministration

$results = @()

# Define the STRICT path endings we are looking for.
$targetEnvironments = @{
    "Police RMS"  = "\ProPhoenix\Police RMS"
    "Fire RMS"    = "\ProPhoenix\Fire RMS"
    "Phoenix IA"  = "\ProPhoenix\PhoenixIA"
}

$sites = Get-Website

foreach ($site in $sites) {
    $bindings = $site.bindings.Collection
    foreach ($binding in $bindings) {
        $protocol = $binding.protocol
        $info = $binding.bindingInformation -split ":"
        $ip = $info[0]; $port = $info[1]; $hostHeader = $info[2]

        # FILTER: Only Port 443
        if ($port -ne "443") { continue }

        if ($ip -eq "*" -and [string]::IsNullOrEmpty($hostHeader)) { $hostname = "localhost" }
        elseif ([string]::IsNullOrEmpty($hostHeader)) { $hostname = $ip }
        else { $hostname = $hostHeader }

        $cleanBaseUrl = "{0}://{1}" -f $protocol, $hostname

        function Get-StrictEnvironmentName ($path) {
            $cleanPath = $path.TrimEnd('\')
            foreach ($key in $targetEnvironments.Keys) {
                $targetEnding = $targetEnvironments[$key]
                if ($cleanPath.EndsWith($targetEnding, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $key
                }
            }
            return $null
        }

        # Root Site Check
        $rootEnv = Get-StrictEnvironmentName -path $site.physicalPath
        if ($rootEnv) {
            $results += [PSCustomObject]@{
                Environment    = $rootEnv
                CleanURL       = "$cleanBaseUrl/"
                LocalDirectory = $site.physicalPath
            }
        }

        # Sub-Application Check
        $applications = Get-WebApplication -Site $site.name
        foreach ($app in $applications) {
            $appEnv = Get-StrictEnvironmentName -path $app.PhysicalPath
            if ($appEnv) {
                $cleanAppUrl = "{0}{1}/" -f $cleanBaseUrl, $app.Path
                $results += [PSCustomObject]@{
                    Environment    = $appEnv
                    CleanURL       = $cleanAppUrl
                    LocalDirectory = $app.PhysicalPath
                }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "Error: No matching environments found in IIS." -ForegroundColor Red
    return
}

Write-Host "Discovered the following environments:" -ForegroundColor Green
$results | Format-Table Environment, CleanURL, LocalDirectory -AutoSize

# =============================================================================
# STEP 2: PREPARE MAPPING (Bridge IIS Names to Config Keys)
# =============================================================================
$configMap = @{
    "Police RMS" = "Police"
    "Fire RMS"   = "Fire"
    "Phoenix IA" = "IA"
}

# =============================================================================
# STEP 3: LOCATE TOOL (BLOB URL OR LOCAL SEARCH)
# =============================================================================
Write-Host "`nStep 3: Locate Tool Source" -ForegroundColor Cyan

# 3A. Prompt User for Input
$blobUrl = Read-Host "Enter Blob URL for 'PnxPrecompilerEXWin.zip' (Press Enter to search local drives)"
$zipPath = $null
$baseTempDir = "C:\PnxTemp" # Default download location

# 3B. Option 1: Download from URL
if (-not [string]::IsNullOrWhiteSpace($blobUrl)) {
    Write-Host "Downloading from Blob URL..." -ForegroundColor Cyan
    
    # Create temp directory if missing
    if (-not (Test-Path $baseTempDir)) { New-Item -ItemType Directory -Force -Path $baseTempDir | Out-Null }
    
    $downloadPath = Join-Path $baseTempDir "PnxPrecompilerEXWin.zip"
    
    try {
        # Using Invoke-WebRequest to download
        Invoke-WebRequest -Uri $blobUrl -OutFile $downloadPath -ErrorAction Stop
        if (Test-Path $downloadPath) {
            $zipPath = $downloadPath
            Write-Host "Download Successful: $zipPath" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error Downloading File: $_" -ForegroundColor Red
        Write-Host "Falling back to local drive search..." -ForegroundColor Yellow
    }
}

# 3C. Option 2: Local Search (Fallback or Default)
if (-not $zipPath) {
    Write-Host "Searching all local drives for 'PnxTemp\PnxPrecompilerEXWin.zip'..." -ForegroundColor Cyan
    
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $tempDir = Join-Path $drive.Root "PnxTemp"
        $testZip = Join-Path $tempDir "PnxPrecompilerEXWin.zip"
        
        if (Test-Path $testZip) {
            $zipPath = $testZip
            Write-Host "Found tool on drive $($drive.Name): $zipPath" -ForegroundColor Green
            $baseTempDir = $tempDir # Update base dir to where we found it
            break 
        }
    }
}

# 3D. Final Check
if (-not $zipPath) {
    Write-Host "Error: Could not find 'PnxPrecompilerEXWin.zip' via URL or Local Drives." -ForegroundColor Red
    return
}

# 3E. Extract
$extractPath = Join-Path $baseTempDir "PnxPrecompilerEXWin"
Write-Host "Extracting Archive..." -ForegroundColor Cyan

try {
    if (-not (Test-Path $extractPath)) { New-Item -ItemType Directory -Force -Path $extractPath | Out-Null }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Write-Host "Extracted to: $extractPath" -ForegroundColor Green
} catch {
    Write-Host "Error Extracting: $_" -ForegroundColor Red
    return
}

# =============================================================================
# STEP 4: UPDATE CONFIG FILE (Targeting ProductsConfig)
# =============================================================================
Write-Host "`nStep 4: Updating PnxPrecompilerWin.exe.config..." -ForegroundColor Cyan

$configPath = Join-Path $extractPath "PnxPrecompilerWin.exe.config"

if (-not (Test-Path $configPath)) {
    Write-Host "Error: Config file not found at $configPath" -ForegroundColor Red
    return
}

$xml = [xml](Get-Content $configPath)
$updatesMade = @()

foreach ($item in $results) {
    $configKey = $configMap[$item.Environment]

    if (-not $configKey) { continue }

    # Look inside <ProductsConfig>
    $node = $xml.SelectSingleNode("//configuration/ProductsConfig/add[@key='$configKey']")
    
    if ($node) {
        $currentValue = $node.value
        $parts = $currentValue -split "\|" 
        
        # Prepare New Data
        $newPath = $item.LocalDirectory
        $newUrl  = $item.CleanURL
        
        # Construct New Value
        $newValue = "$newPath|$newUrl"
        
        # Preserve Extras
        if ($parts.Count -gt 2) {
            $newValue = "$newValue|$($parts[2])"
        }

        # Update XML
        $node.value = $newValue

        # Add to display list
        $updatesMade += [PSCustomObject]@{
            Key = $configKey
            Status = "Updated"
            NewValue = $newValue
        }
    } else {
        $updatesMade += [PSCustomObject]@{
            Key = $configKey
            Status = "Missing in Config"
            NewValue = "N/A"
        }
    }
}

$xml.Save($configPath)

# DISPLAY THE UPDATE STATUS
Write-Host "`n--- Update Status Report ---" -ForegroundColor Yellow
$updatesMade | Format-Table Key, Status, NewValue -AutoSize
Write-Host "Configuration saved successfully!" -ForegroundColor Cyan