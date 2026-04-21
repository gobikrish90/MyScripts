# ====================================================================
# Universal IIS Configuration & Deployment Script
# ====================================================================

# 1. Enforce Administrator Privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "❌ This script must be run as an Administrator. Please elevate your prompt."
    break
}

# 2. Detect OS Environment
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$isServer = $osInfo.ProductType -ne 1 # 1 = Workstation (Win 10/11), 2/3 = Server

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   Starting IIS Deployment                         " -ForegroundColor Cyan
Write-Host "   OS Detected: $($osInfo.Caption)                 " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

$pendingRestart = $false

# ====================================================================
# SERVER OS EXECUTION PATH
# ====================================================================
if ($isServer) {
    
    # Batch 1: Modern Features (Safe, high-speed installation)
    $modernFeatures = @(
        "Web-Server", "Web-WebServer", "Web-Common-Http", "Web-Static-Content",
        "Web-Default-Doc", "Web-Dir-Browsing", "Web-Http-Errors", "Web-Http-Redirect",
        "Web-Ftp-Server", "Web-Ftp-Service", "Web-Asp-Net45", "Web-Net-Ext45", 
        "Web-ISAPI-Ext", "Web-ISAPI-Filter", "Web-AppInit", "Web-Asp", "Web-CGI",
        "Web-Http-Logging", "Web-Log-Libraries", "Web-Request-Monitor", "Web-Http-Tracing",
        "Web-Basic-Auth", "Web-Digest-Auth", "Web-Windows-Auth",
        "Web-Stat-Compression", "Web-Dyn-Compression",
        "Web-Mgmt-Console", "Web-Metabase", "Web-WMI", "Web-Lgcy-Mgmt-Console",
        "NET-Framework-45-Core", "NET-Framework-45-ASPNET", 
        "NET-WCF-HTTP-Activation45", "NET-WCF-TCP-PortSharing45"
    )

    # Batch 2: Legacy Features (Isolated to prevent WSUS rollback)
    $legacyFeatures = @("NET-Framework-Core", "NET-Http-Activation", "Web-Asp-Net", "Web-Net-Ext")
    $allServerFeatures = $modernFeatures + $legacyFeatures

    # --- Install Batch 1 ---
    Write-Host "`n⏳ [Phase 1] Installing Modern IIS Features..." -ForegroundColor Yellow
    try {
        $result1 = Install-WindowsFeature -Name $modernFeatures -ErrorAction Stop
        if ($result1.RestartNeeded -eq 'Yes') { $pendingRestart = $true }
    } catch {
        Write-Warning "Phase 1 encountered an issue: $_"
    }

    # --- Install Batch 2 ---
    Write-Host "⏳ [Phase 2] Attempting Legacy .NET 3.5 Features..." -ForegroundColor Yellow
    try {
        $result2 = Install-WindowsFeature -Name $legacyFeatures -ErrorAction Stop
        if ($result2.RestartNeeded -eq 'Yes') { $pendingRestart = $true }
    } catch {
        Write-Warning "Legacy .NET 3.5 blocked by WSUS (0x800f0954). Will require offline source later."
    }

    # --- Generate Status Report ---
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "   Installation Status Report                      " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    
    $featureStatus = Get-WindowsFeature -Name $allServerFeatures
    foreach ($feature in $featureStatus) {
        if ($feature.InstallState -eq "Installed") {
            Write-Host "  [✔] $($feature.DisplayName)" -ForegroundColor Green
        } else {
            Write-Host "  [❌] $($feature.DisplayName) (Missing/Blocked)" -ForegroundColor Red
        }
    }
} 
# ====================================================================
# CLIENT OS (WINDOWS 10/11) EXECUTION PATH
# ====================================================================
else {
    Write-Host "`n⏳ Configuring Windows Client IIS Features..." -ForegroundColor Yellow
    
    # Client features map to different names and use DISM/OptionalFeatures
    $clientFeatures = @(
        "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-StaticContent", 
        "IIS-DefaultDocument", "IIS-DirectoryBrowsing", "IIS-HttpErrors", "IIS-HttpRedirect", 
        "IIS-FTPServer", "IIS-FTPSvc", "IIS-ASPNET45", "IIS-NetFxExtensibility45", 
        "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-ApplicationInit", "IIS-ASP", "IIS-CGI", 
        "IIS-HttpLogging", "IIS-LoggingLibraries", "IIS-RequestMonitor", "IIS-HttpTracing", 
        "IIS-BasicAuthentication", "IIS-DigestAuthentication", "IIS-WindowsAuthentication", 
        "IIS-HttpCompressionStatic", "IIS-HttpCompressionDynamic", "IIS-ManagementConsole", 
        "IIS-IIS6ManagementCompatibility", "IIS-Metabase", "IIS-WMICompatibility", "IIS-LegacySnapIn",
        "WCF-HTTP-Activation45", "WCF-TCP-PortSharing45"
    )

    # Note: Client OS occasionally uses NetFx3 for .NET 3.5, which we will separate
    $clientLegacy = @("NetFx3", "IIS-ASPNET", "IIS-NetFxExtensibility")
    $allClientFeatures = $clientFeatures + $clientLegacy

    # Enable Modern Client Features
    foreach ($feature in $clientFeatures) {
        $res = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
        if ($res.RestartNeeded -eq $true) { $pendingRestart = $true }
    }

    # Enable Legacy Client Features
    foreach ($feature in $clientLegacy) {
        $res = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
        if ($res.RestartNeeded -eq $true) { $pendingRestart = $true }
    }

    # --- Generate Status Report ---
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "   Installation Status Report                      " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan

    foreach ($feature in $allClientFeatures) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature).State
        if ($state -eq "Enabled") {
            Write-Host "  [✔] $feature" -ForegroundColor Green
        } else {
            Write-Host "  [❌] $feature (Missing/Blocked)" -ForegroundColor Red
        }
    }
}

# ====================================================================
# FINALIZE SERVICES
# ====================================================================
Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "   Starting Services                               " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

$services = @("W3SVC", "IISADMIN", "ftpsvc")
foreach ($service in $services) {
    if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
        Set-Service -Name $service -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $service -ErrorAction SilentlyContinue
        Write-Host "  [✔] $service is configured to Automatic and Running." -ForegroundColor Green
    } else {
        Write-Host "  [⚠️] $service is not present on this system." -ForegroundColor DarkYellow
    }
}

if ($pendingRestart) {
    Write-Host "`n⚠️ ATTENTION: A system restart is required for all features to fully activate." -ForegroundColor Yellow
    Write-Host "⚠️ The system will NOT restart automatically." -ForegroundColor Yellow
}

Write-Host "`n🚀 Deployment Script Finished." -ForegroundColor Cyan