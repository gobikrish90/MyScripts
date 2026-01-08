# =============================================================================
# PHOENIX PRECOMPILER: SINGLE INSTANCE LAUNCH
# =============================================================================

# --- STEP 1: DISCOVER IIS ENVIRONMENTS (STRICT FILTER) ---
Write-Host "Step 1: Discovering IIS Bindings..." -ForegroundColor Cyan

# Check for Admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator to access IIS settings."
    Break
}

Import-Module WebAdministration

$results = @()

# STRICT WHITELIST: Only these folders are allowed.
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
                if ($cleanPath.EndsWith($targetEnvironments[$key], [System.StringComparison]::OrdinalIgnoreCase)) { return $key }
            }
            return $null
        }

        # Check Root Site
        $rootEnv = Get-StrictEnvironmentName -path $site.physicalPath
        if ($rootEnv) {
            $results += [PSCustomObject]@{ Environment = $rootEnv; CleanURL = "$cleanBaseUrl/"; LocalDirectory = $site.physicalPath }
        }

        # Check Sub-Applications
        $applications = Get-WebApplication -Site $site.name
        foreach ($app in $applications) {
            $appEnv = Get-StrictEnvironmentName -path $app.PhysicalPath
            if ($appEnv) {
                $results += [PSCustomObject]@{ Environment = $appEnv; CleanURL = "{0}{1}/" -f $cleanBaseUrl, $app.Path; LocalDirectory = $app.PhysicalPath }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "Error: No matching environments (Police/Fire/IA) found in IIS." -ForegroundColor Red
    return
}
$results | Format-Table Environment, CleanURL, LocalDirectory -AutoSize

# --- STEP 2: PREPARE MAPPING ---
$configMap = @{ "Police RMS" = "Police"; "Fire RMS" = "Fire"; "Phoenix IA" = "IA" }

# --- STEP 3: DOWNLOAD TOOL (GOOGLE DRIVE) ---
Write-Host "`nStep 3: Downloading Tool from Google Drive..." -ForegroundColor Cyan

# Google Drive Direct Download Link
$fileId = "1uMoWSYddk3dRzaDwmkD-cEjsrRpJKu-x"
$downloadUrl = "https://drive.google.com/uc?export=download&id=$fileId"

$zipPath = $null
if (Test-Path "D:\PnxTemp") { $baseTempDir = "D:\PnxTemp" } else { $baseTempDir = "C:\PnxTemp" }

# STOP RUNNING PROCESSES (Prevents Access Denied)
Write-Host "Checking for running instances of PnxPrecompilerWin..." -ForegroundColor Yellow
$runningProcs = Get-Process "PnxPrecompilerWin" -ErrorAction SilentlyContinue
if ($runningProcs) {
    Write-Host "Stopping $($runningProcs.Count) running instances..." -ForegroundColor Yellow
    $runningProcs | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# DOWNLOAD
if (-not (Test-Path $baseTempDir)) { New-Item -ItemType Directory -Force -Path $baseTempDir | Out-Null }
$downloadPath = Join-Path $baseTempDir "PnxPrecompilerEXWin.zip"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
    if (Test-Path $downloadPath) { 
        $zipPath = $downloadPath 
        Write-Host "Download Successful." -ForegroundColor Green
    }
} catch {
    Write-Host "Google Drive Download failed: $_" -ForegroundColor Red
    Write-Host "Trying local search..." -ForegroundColor Yellow
}

# FALLBACK SEARCH
if (-not $zipPath) {
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $testZip = Join-Path $drive.Root "PnxTemp\PnxPrecompilerEXWin.zip"
        if (Test-Path $testZip) { $zipPath = $testZip; $baseTempDir = Join-Path $drive.Root "PnxTemp"; break }
    }
}

if (-not $zipPath) { Write-Host "Error: Tool zip not found." -ForegroundColor Red; return }

$extractPath = Join-Path $baseTempDir "PnxPrecompilerEXWin"

try { 
    Write-Host "Extracting to: $extractPath" -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force 
} catch { 
    Write-Host "Error Extracting: $_" -ForegroundColor Red
    return 
}

# --- STEP 4: UPDATE CONFIG ---
Write-Host "`nStep 4: Updating Config..." -ForegroundColor Cyan
$configPath = Join-Path $extractPath "PnxPrecompilerWin.exe.config"
$xml = [xml](Get-Content $configPath)
foreach ($item in $results) {
    $configKey = $configMap[$item.Environment]
    if ($configKey) {
        $node = $xml.SelectSingleNode("//configuration/ProductsConfig/add[@key='$configKey']")
        if ($node) {
            $parts = $node.value -split "\|"
            $newValue = "$($item.LocalDirectory)|$($item.CleanURL)"
            if ($parts.Count -gt 2) { $newValue = "$newValue|$($parts[2])" }
            $node.value = $newValue
        }
    }
}
$xml.Save($configPath)
Write-Host "Config updated." -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green