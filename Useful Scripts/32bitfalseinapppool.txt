# 1. Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "You are not running as Administrator. Please run this as Admin."
    break
}

Import-Module WebAdministration -ErrorAction Stop

# Get all Application Pools
$appPools = Get-ChildItem "IIS:\AppPools"

foreach ($pool in $appPools) {
    $poolName = $pool.Name

    # --- SAFETY FILTER ---
    # logic: If the name matches "DefaultAppPool" OR starts with ".NET" OR is "Classic .NET AppPool"
    if ($poolName -eq "DefaultAppPool" -or $poolName -like ".NET*" -or $poolName -eq "Classic .NET AppPool") {
        Write-Host "[EXEMPT]  $($poolName): System pool. Leaving untouched." -ForegroundColor DarkGray
        continue # Skip to the next pool immediately
    }
    # ---------------------

    # Check the current value of 'enable32BitAppOnWin64'
    $is32BitEnabled = Get-ItemProperty "IIS:\AppPools\$poolName" -Name "enable32BitAppOnWin64"

    if ($is32BitEnabled.Value -eq $true) {
        # Change it to False
        Set-ItemProperty "IIS:\AppPools\$poolName" -Name "enable32BitAppOnWin64" -Value $false
        
        Write-Host "[CHANGED] $($poolName): 'Enable 32-Bit' was True, now set to False." -ForegroundColor Cyan
    }
    else {
        # Already False, so skip
        Write-Host "[SKIPPED] $($poolName): 'Enable 32-Bit' is already False." -ForegroundColor Gray
    }
}