# =============================================================================
# PHOENIX PRECOMPILER: Installation Team
# =============================================================================

# --- STEP 1: DISCOVER IIS ENVIRONMENTS (STRICT FILTER) ---
Write-Host "Step 1: Discovering IIS Bindings..." -ForegroundColor Cyan

# Check for Admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator."
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

        $rootEnv = Get-StrictEnvironmentName -path $site.physicalPath
        if ($rootEnv) {
            $results += [PSCustomObject]@{ Environment = $rootEnv; CleanURL = "$cleanBaseUrl/"; LocalDirectory = $site.physicalPath }
        }

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

# --- STEP 3: LOCATE LOCAL TOOL TARGET ---
Write-Host "`nStep 3: Locate Local Installation" -ForegroundColor Cyan

# STOP RUNNING PROCESSES
Write-Host "Checking for running instances of PnxPrecompilerWin..." -ForegroundColor Yellow
$runningProcs = Get-Process "PnxPrecompilerWin" -ErrorAction SilentlyContinue
if ($runningProcs) {
    Write-Host "Stopping $($runningProcs.Count) running instances..." -ForegroundColor Yellow
    $runningProcs | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$WorkingPath = $null
Write-Host "Searching local drives for installed 'PhoenixPrecompileEx' folder..." -ForegroundColor Cyan

$targetPartialPath = "Program Files (x86)\ProPhoenix\Server Application Manager\PhoenixPrecompileEx"
$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {
    $potentialPath = Join-Path $drive.Root $targetPartialPath
    if (Test-Path $potentialPath) {
        $WorkingPath = $potentialPath
        Write-Host "Found installed tool at: $WorkingPath" -ForegroundColor Green
        break
    }
}

if (-not $WorkingPath) {
    Write-Host "Error: Tool folder not found on any local drive." -ForegroundColor Red
    return 
}

# --- STEP 4: UPDATE JSON CONFIG (SPECIFIC STRUCTURE) ---
Write-Host "`nStep 4: Updating JSON Config File..." -ForegroundColor Cyan
Write-Host "Target: $WorkingPath" -ForegroundColor Gray

$jsonPath = Join-Path $WorkingPath "products.config.json"

if (-not (Test-Path $jsonPath)) {
    Write-Host "Error: JSON Config file missing at $jsonPath" -ForegroundColor Red
    return
}

try {
    # 1. READ JSON
    $jsonContent = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
    $updatesCount = 0

    # 2. VALIDATE STRUCTURE
    if (-not $jsonContent.PSObject.Properties['Products']) {
        Write-Host "Error: Invalid JSON format. Root property 'Products' is missing." -ForegroundColor Red
        return
    }

    # 3. UPDATE LOOP
    foreach ($item in $results) {
        $targetName = $configMap[$item.Environment] # e.g., "Police", "Fire", "IA"
        if (-not $targetName) { continue }

        # Find the product object inside the 'Products' array
        $productEntry = $jsonContent.Products | Where-Object { $_.Name -eq $targetName }

        if ($productEntry) {
            Write-Host " -> Updating '$targetName'..." -ForegroundColor Yellow
            
            # Update BasePath
            if ($productEntry.BasePath -ne $item.LocalDirectory) {
                $productEntry.BasePath = $item.LocalDirectory
                Write-Host "    [BasePath] Updated" -ForegroundColor Gray
            }
            
            # Update Url
            if ($productEntry.Url -ne $item.CleanURL) {
                $productEntry.Url = $item.CleanURL
                Write-Host "    [Url] Updated" -ForegroundColor Gray
            }

            $updatesCount++
        } else {
            Write-Host " -> Warning: Product '$targetName' not found in JSON." -ForegroundColor Red
        }
    }

    # 4. SAVE JSON
    if ($updatesCount -gt 0) {
        # Depth 10 preserves the nested 'CriticalModules' array
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath
        Write-Host "Success! Updated $updatesCount products in products.config.json." -ForegroundColor Green
    } else {
        Write-Host "No changes were needed." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Error parsing or saving JSON: $_" -ForegroundColor Red
}

Write-Host "Script Complete." -ForegroundColor Green