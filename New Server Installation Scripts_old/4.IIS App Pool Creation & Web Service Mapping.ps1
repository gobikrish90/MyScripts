# Requires elevated privileges (Run as Administrator)

# --- Configuration Variables ---

# Define the names of the application pools
$appPoolNames = @(
    "PhoenixPolice", "PhoenixFire", "PhoenixIA", "NIBRS", "PnxRptSvr", "KGISPD",
    "PhoenixPDFService", "ProvisionManager", "Webservice", "FireWS", "WDAApp",
    "UserDocs", "ADR"
)

# These application pools need to be set to "No Managed Code"
$noManagedCodeAppPools = @("WDAV2API", "PnxDiagram", "PnxDiagramAPI")

# Application pools that require advanced settings (Idle Time-out Action: Suspend)
$advancedSettingsPools = @("PhoenixPolice", "PhoenixFire", "PhoenixIA")

# Special RMS pool that requires Rapid-Fail Protection Enabled to False
$specialRMSPool = "PhoenixPolice"

# Path to appcmd.exe
$appCmdPath = "$env:windir\system32\inetsrv\appcmd.exe"

# Default Web Site Name
$DEFAULT_SITE = "Default Web Site"

# Default Web Site Applications and their corresponding Application Pools
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
}

# --- Functions ---

function Test-AppPoolExists {
    param (
        [string]$Name
    )
    # Check if the application pool exists using appcmd
    $result = & $appCmdPath list apppool /name:$Name /text:name 2>$null
    return -not [string]::IsNullOrEmpty($result)
}

function New-ApplicationPool {
    param (
        [string]$Name
    )
    Write-Host "Creating application pool '$Name'..."
    try {
        & $appCmdPath add apppool /name:$Name | Out-Null
        if (Test-AppPoolExists -Name $Name) {
            Write-Output "Application pool '$Name' was successfully created."
            return $true
        } else {
            Write-Error "Failed to create application pool '$Name'."
            return $false
        }
    } catch {
        Write-Error "Error creating application pool '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolIdentity {
    param (
        [string]$Name,
        [string]$IdentityType = "NetworkService"
    )
    Write-Output "Setting identity for '$Name' to '$IdentityType'..."
    try {
        & $appCmdPath set apppool /apppool.name:$Name /processModel.identityType:$IdentityType | Out-Null
        Write-Output "Application pool '$Name' identity updated successfully."
        return $true
    } catch {
        Write-Error "Error setting identity for '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolManagedRuntimeVersion {
    param (
        [string]$Name,
        [string]$Version = "v4.0"
    )
    Write-Output "Setting '$Name' to .NET CLR version '$Version'."
    try {
        & $appCmdPath set apppool /apppool.name:$Name /managedRuntimeVersion:$Version | Out-Null
        return $true
    } catch {
        Write-Error "Error setting managed runtime version for '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolEnable32BitAppOnWin64 {
    param (
        [string]$Name,
        [bool]$Enable = $false
    )
    Write-Output "Setting '$Name' 32-bit Applications to '$Enable'."
    try {
        & $appCmdPath set apppool /apppool.name:$Name /enable32BitAppOnWin64:$Enable | Out-Null
        return $true
    } catch {
        Write-Error "Error setting 32-bit applications for '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolIdleTimeoutAction {
    param (
        [string]$Name,
        [string]$Action = "Suspend"
    )
    Write-Output "Setting '$Name' Idle Time-out Action to '$Action'."
    try {
        & $appCmdPath set apppool /apppool.name:$Name /processModel.idleTimeoutAction:$Action | Out-Null
        return $true
    } catch {
        Write-Error "Error setting idle timeout action for '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-AppPoolRapidFailProtection {
    param (
        [string]$Name,
        [bool]$Enabled = $false
    )
    Write-Output "Setting '$Name' Rapid-Fail Protection to '$Enabled'."
    try {
        & $appCmdPath set apppool /apppool.name:$Name /failure.rapidFailProtection:$Enabled | Out-Null
        return $true
    } catch {
        Write-Error "Error setting rapid fail protection for '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Set-IISApplicationPool {
    param (
        [string]$SiteName,
        [string]$AppName,
        [string]$AppPoolName
    )

    Write-Host "Setting application pool for '$AppName' under '$SiteName' to '$AppPoolName'..."
    try {
        # This assumes the application already exists under the given site
        & "$env:windir\system32\inetsrv\appcmd" set app /app.name:"$SiteName/$AppName" /applicationPool:$AppPoolName | Out-Null
        Write-Host "Application pool for '$AppName' under '$SiteName' has been successfully set to '$AppPoolName'."
        return $true
    } catch {
        Write-Warning "Failed to set application pool for '$AppName' under '$SiteName'. Please ensure the application and pool exist. Error: $($_.Exception.Message)"
        return $false
    }
}

function Set-PhoenixPDFServiceAdvancedSettings {
    param (
        [string]$AppPoolName
    )
    Write-Host "Configuring Advanced Settings for '$AppPoolName' Application Pool..."
    if (Test-AppPoolExists -Name $AppPoolName) {
        try {
            # Set idle timeout to 20 minutes (00:20:00)
            Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name "processModel.idleTimeout" -Value "00:20:00"
            # Set periodic restart time to 5 minutes (00:05:00)
            # WARNING: 5 minutes is a very frequent recycle time and might impact application availability.
            # Consider a longer duration (e.g., "1.00:00:00" for daily) for production environments.
            Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name "recycling.periodicRestart.time" -Value "00:05:00"
            Write-Host "Advanced settings applied to application pool '$AppPoolName'."
            return $true
        } catch {
            Write-Error "Failed to set advanced settings for application pool '$AppPoolName': $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-Host "Application pool '$AppPoolName' does not exist, advanced settings cannot be applied."
        return $false
    }
}

function Set-ServiceRecoveryActions {
    param (
        [string]$ServiceName
    )

    Write-Output "Attempting to update recovery actions for service: '$ServiceName'."
    try {
        # Set recovery actions to restart the service on first, second, and subsequent failures
        $command = "sc.exe failure `"$ServiceName`" reset= 0 actions= restart/60000/restart/60000/restart/60000"
        Invoke-Expression $command | Out-Null
        Write-Output "Updated recovery actions for service: '$ServiceName'."
        return $true
    } catch {
        Write-Warning "Failed to update recovery actions for service '$ServiceName': $($_.Exception.Message)"
        return $false
    }
}

# --- Main Script Execution ---

Write-Host "Starting IIS and Service Configuration Script..."
Write-Host "------------------------------------------------"

# Import WebAdministration module if not already loaded (for Set-ItemProperty)
Import-Module WebAdministration -ErrorAction SilentlyContinue

Write-Host "`n### Configuring IIS Application Pools ###"

# Combine all application pool names for iteration
$allAppPoolsToProcess = $appPoolNames + $noManagedCodeAppPools | Select-Object -Unique

foreach ($appPoolName in $allAppPoolsToProcess) {
    Write-Host "`n--- Processing Application Pool: '$appPoolName' ---"

    $poolExists = Test-AppPoolExists -Name $appPoolName
    if ($poolExists) {
        Write-Output "Application pool '$appPoolName' already exists."
    } else {
        if (-not (New-ApplicationPool -Name $appPoolName)) {
            continue # Skip to the next app pool if creation failed
        }
    }

    # Set the identity to NetworkService
    Set-AppPoolIdentity -Name $appPoolName

    # Set Managed Runtime Version
    if ($noManagedCodeAppPools -contains $appPoolName) {
        Set-AppPoolManagedRuntimeVersion -Name $appPoolName -Version "" # No Managed Code
    } else {
        Set-AppPoolManagedRuntimeVersion -Name $appPoolName -Version "v4.0"
    }

    # Enable 32-bit Applications (always set to False as per original script)
    Set-AppPoolEnable32BitAppOnWin64 -Name $appPoolName -Enable $false

    # Set Idle Time-out Action to Suspend for specific application pools
    if ($appPoolName -in $advancedSettingsPools) {
        Set-AppPoolIdleTimeoutAction -Name $appPoolName -Action "Suspend"
    }

    # Set Rapid-Fail Protection Enabled to False for the special RMS pool
    if ($appPoolName -eq $specialRMSPool) {
        Set-AppPoolRapidFailProtection -Name $appPoolName -Enabled $false
    }
}

Write-Host "`n### Configuring Applications under '$DEFAULT_SITE' ###"

foreach ($app in $applications.Keys) {
    $pool = $applications[$app]
    Write-Host "`n--- Configuring Application: '$app' (using Pool: '$pool') ---"

    if (-not (Test-AppPoolExists -Name $pool)) {
        Write-Warning "Application pool '$pool' for application '$app' does not exist. Creating it now."
        if (-not (New-ApplicationPool -Name $pool)) {
            Write-Error "Skipping configuration for application '$app' due to application pool creation failure."
            continue # Skip to the next application if pool creation fails
        }
    }

    Set-IISApplicationPool -SiteName $DEFAULT_SITE -AppName $app -AppPoolName $pool
}

Write-Host "`n### Configuring Advanced Settings for PhoenixPDFService ###"

$phoenixPdfAppPoolName = "PhoenixPDFService"
Set-PhoenixPDFServiceAdvancedSettings -AppPoolName $phoenixPdfAppPoolName

Write-Host "`n### Configuring Service Recovery Actions ###"

# Get all services starting with "Phoenix"
$phoenixServices = Get-Service | Where-Object { $_.Name -like "Phoenix*" }

Write-Host "`n--- Updating recovery actions for Phoenix services ---"
foreach ($service in $phoenixServices) {
    Set-ServiceRecoveryActions -ServiceName $service.Name
}

Write-Host "`n--- Updating recovery actions for 'aspnet_state' service ---"
Set-ServiceRecoveryActions -ServiceName "aspnet_state"

Write-Output "`nAll specified IIS application pools, applications, and service recovery actions have been processed."

# Pause for user input to keep the console window open after script execution
Read-Host -Prompt "Press Enter to exit"