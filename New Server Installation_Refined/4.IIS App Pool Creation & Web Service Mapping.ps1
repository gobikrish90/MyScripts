# Requires elevated privileges (Run as Administrator)

# --- Configuration Variables ---
$LogPath = "C:\Scripts\IIS_Config_Log.txt"
$appPoolNames = @(
    "PhoenixPolice", "PhoenixFire", "PhoenixIA", "NIBRS", "PnxRptSvr", "KGISPD",
    "PhoenixPDFService", "ProvisionManager", "Webservice", "FireWS", "WDAApp",
    "UserDocs", "ADR"
)

$noManagedCodeAppPools = @("WDAV2API", "PnxDiagram", "PnxDiagramAPI", "PhoenixInspectionAPI")
$advancedSettingsPools = @("PhoenixPolice", "PhoenixFire", "PhoenixIA")
$specialRMSPool = "PhoenixPolice"
$appCmdPath = "$env:windir\system32\inetsrv\appcmd.exe"
$DEFAULT_SITE = "Default Web Site"

$applications = @{
    "Law"               = "PhoenixPolice";
    "Fire"              = "PhoenixFire";
    "IA"                = "PhoenixIA";
    "ADR"               = "ADR";
    "NIBRSService"      = "NIBRS";
    "PnxRptSvr"         = "PnxRptSvr";
    "KGIS"              = "KGISPD";
    "ProvisionManager"  = "ProvisionManager";
    "Webservice"        = "Webservice";
    "FireWS"            = "FireWS";
    "WDAApp"            = "WDAApp";
    "PhoenixPDFService" = "PhoenixPDFService";
    "PnxDiagram"        = "PnxDiagram";
    "PnxDiagramAPI"     = "PnxDiagramAPI";
    "UserDocs"          = "UserDocs";
    "WDAV2API"          = "WDAV2API"
    "PhoenixInspectionAPI" = "PhoenixInspectionAPI"
}

# --- Functions ---

function Test-AppPoolExists {
    param ([string]$Name)
    $result = & $appCmdPath list apppool /name:"$Name" /text:name 2>$null
    return -not [string]::IsNullOrEmpty($result)
}

function New-ApplicationPool {
    param ([string]$Name)
    if (Test-AppPoolExists -Name $Name) { 
        Write-Output "App Pool '$Name' already exists. Skipping creation."
        return $true 
    }
    Write-Host "Creating application pool '$Name'..." -ForegroundColor Cyan
    try {
        & $appCmdPath add apppool /name:"$Name" | Out-Null
        return $true
    } catch {
        Write-Error "Failed to create application pool '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolProperty {
    param (
        [string]$Name,
        [string]$Property,
        [string]$Value
    )
    try {
        & $appCmdPath set apppool /apppool.name:"$Name" /"$Property":"$Value" | Out-Null
        Write-Output "Successfully set $Property to $Value for $Name"
    } catch {
        Write-Warning "Failed to set $Property for $Name"
    }
}

function Set-ServiceRecovery {
    param ([string]$ServiceName)
    Write-Output "Configuring recovery for: $ServiceName"
    # Reset fail count after 1 day (86400s), restart after 1 min (60000ms)
    $scCmd = "sc.exe failure `"$ServiceName`" reset= 86400 actions= restart/60000/restart/60000/restart/60000"
    Invoke-Expression $scCmd | Out-Null
}

# --- Main Script Execution ---

Start-Transcript -Path $LogPath -Append
Write-Host "--- Starting Configuration at $(Get-Date) ---" -ForegroundColor Green

Import-Module WebAdministration -ErrorAction SilentlyContinue

# 1. Process Application Pools
$allPools = $appPoolNames + $noManagedCodeAppPools | Select-Object -Unique

foreach ($pool in $allPools) {
    if (New-ApplicationPool -Name $pool) {
        Set-AppPoolProperty -Name $pool -Property "processModel.identityType" -Value "NetworkService"
        Set-AppPoolProperty -Name $pool -Property "enable32BitAppOnWin64" -Value "false"
        
        # Managed Code Logic
        $runtime = if ($noManagedCodeAppPools -contains $pool) { "" } else { "v4.0" }
        Set-AppPoolProperty -Name $pool -Property "managedRuntimeVersion" -Value $runtime

        # Idle Action Suspend
        if ($advancedSettingsPools -contains $pool) {
            Set-AppPoolProperty -Name $pool -Property "processModel.idleTimeoutAction" -Value "Suspend"
        }

        # Rapid Fail Protection
        if ($pool -eq $specialRMSPool) {
            Set-AppPoolProperty -Name $pool -Property "failure.rapidFailProtection" -Value "false"
        }
    }
}

# 2. Map Applications to Pools
foreach ($app in $applications.Keys) {
    $pool = $applications[$app]
    try {
        & $appCmdPath set app /app.name:"$DEFAULT_SITE/$app" /applicationPool:"$pool" | Out-Null
        Write-Host "Mapped $app to $pool" -ForegroundColor Gray
    } catch {
        Write-Warning "Could not map $app. Ensure the virtual directory exists."
    }
}

# 3. Specialized PDF Service Fix
# Corrected from 5 minutes to 24 hours (1.00:00:00) to prevent performance thrashing
Write-Host "Applying stability fix to PhoenixPDFService..."
Set-ItemProperty "IIS:\AppPools\PhoenixPDFService" -Name "processModel.idleTimeout" -Value "00:20:00"
Set-ItemProperty "IIS:\AppPools\PhoenixPDFService" -Name "recycling.periodicRestart.time" -Value "1.00:00:00"

# 4. Service Recovery
Get-Service -Name "Phoenix*", "aspnet_state" -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ServiceRecovery -ServiceName $_.Name
}

Write-Host "--- Configuration Complete. Log saved to $LogPath ---" -ForegroundColor Green
Stop-Transcript
Read-Host -Prompt "Press Enter to exit"