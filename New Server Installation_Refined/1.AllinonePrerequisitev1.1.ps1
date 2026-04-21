# ==============================================================================
# ProPhoenix Pre - requisite
# Version: 4.0
# ==============================================================================

$ErrorActionPreference = "Stop"

# --- 1. Admin & Environment Check ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "CRITICAL: Please run PowerShell as Administrator."
    exit
}

# --- 2. Global Status Tracker ---
$global:ExecutionSummary = [System.Collections.Generic.List[PSCustomObject]]::new()

Function Record-TaskStatus {
    param([string]$TaskName, [string]$Status, [string]$Details = "")
    $global:ExecutionSummary.Add([PSCustomObject]@{
        Task    = $TaskName
        Status  = $Status
        Details = $Details
    })
}

# --- 3. User Configuration Inputs ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  System Configuration Initialization" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$installDrive = (Read-Host "Enter Primary Installation Drive Letter (e.g., C)").ToUpper()
if ($installDrive -notmatch "^[A-Z]$") { Write-Error "Invalid drive letter."; exit 1 }

$phoenixAppManagerInstallDrive = (Read-Host "Enter Phoenix App Manager Install Drive (e.g., C)").ToUpper()
if ($phoenixAppManagerInstallDrive -notmatch "^[A-Z]$") { Write-Error "Invalid drive letter."; exit 1 }

$backupDrive = (Read-Host "Enter Backup/Logs Drive Letter for machine.config (e.g., D)").ToUpper()
if ($backupDrive -notmatch "^[A-Z]$") { Write-Error "Invalid drive letter."; exit 1 }

# --- 4. Directory & Logging Setup ---
$tempInstallPath = "${installDrive}:\PnxTemp"
if (!(Test-Path -Path $tempInstallPath)) { New-Item -Path $tempInstallPath -ItemType Directory -Force | Out-Null }

$phoenixAppManagerTempPath = "${phoenixAppManagerInstallDrive}:\PnxTemp"
if (!(Test-Path -Path $phoenixAppManagerTempPath)) { New-Item -Path $phoenixAppManagerTempPath -ItemType Directory -Force | Out-Null }

$script:LogFilePath = "$tempInstallPath\SystemSetup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Function Write-Log {
    param([string]$Message, [string]$Level = "INFO", [switch]$NoConsole)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if (-not [string]::IsNullOrEmpty($script:LogFilePath)) {
        Add-Content -Path $script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
    }
    
    if (-not $NoConsole) {
        switch ($Level) {
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            default { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
}

Write-Log "Initialization complete. Log path: $script:LogFilePath"

# --- 5. Helper Functions ---

Function Get-FipsRegistryStatus {
    try {
        $fipsEnabled = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name "Enabled" -ErrorAction Stop).Enabled
        return ($fipsEnabled -eq 1)
    } catch { return $false }
}

# Standard Installer (MSI/EXE)
Function Install-Package {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [Parameter(Mandatory=$true)][string]$SoftwareName,
        [string[]]$InstallArgs = @("/passive", "/norestart", "/qn"),
        [string]$UninstallDisplayName
    )

    Write-Log "`nProcessing: $SoftwareName"
    
    if ($UninstallDisplayName) {
        $uninstallPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
        if (Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$UninstallDisplayName*" }) {
            Write-Log "$SoftwareName is already installed. Skipping." -Level SUCCESS
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Skipped" -Details "Already Installed"
            return
        }
    }

    try {
        Write-Log "Downloading $SoftwareName..."
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop

        Write-Log "Installing $SoftwareName..."
        $process = if ($DestinationPath.ToLower().EndsWith(".msi")) {
            Start-Process "msiexec.exe" -ArgumentList ("/i `"$DestinationPath`" " + ($InstallArgs -join " ")) -Wait -PassThru -ErrorAction Stop
        } else { 
            Start-Process $DestinationPath -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop
        }

        if ($process.ExitCode -in @(0, 3010)) {
            Write-Log "$SoftwareName installed successfully." -Level SUCCESS
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Success" -Details $(if ($process.ExitCode -eq 3010) {"Reboot Required"} else {"Success"})
            Remove-Item -Path $DestinationPath -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Write-Log "Installation failed. Code: $($process.ExitCode)." -Level ERROR
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Failed" -Details "Exit Code: $($process.ExitCode)"
        }
    } catch {
        Write-Log "Error: $($_.Exception.Message)" -Level ERROR
        Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Failed" -Details "Exception Occurred"
    }
}

# NEW FUNCTION: Handles ZIP files
Function Install-ZippedPackage {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$ZipPath,
        [Parameter(Mandatory=$true)][string]$ExtractFolder,
        [Parameter(Mandatory=$true)][string]$InstallerFileName,
        [Parameter(Mandatory=$true)][string]$SoftwareName,
        [string[]]$InstallArgs = @("/passive", "/norestart", "/qn"),
        [string]$UninstallDisplayName,
        [string]$InstallDirectory
    )

    Write-Log "`nProcessing ZIPPED Package: $SoftwareName"
    
    if ($UninstallDisplayName) {
        $uninstallPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
        if (Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$UninstallDisplayName*" }) {
            Write-Log "$SoftwareName is already installed. Skipping." -Level SUCCESS
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Skipped" -Details "Already Installed"
            return
        }
    }

    try {
        # 1. Download
        Write-Log "Downloading ZIP for $SoftwareName..."
        Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

        # 2. Extract
        Write-Log "Extracting ZIP..."
        if (Test-Path $ExtractFolder) { Remove-Item $ExtractFolder -Recurse -Force -ErrorAction SilentlyContinue }
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractFolder -Force

        # 3. Locate Installer
        $installerPath = Join-Path $ExtractFolder $InstallerFileName
        if (-not (Test-Path $installerPath)) {
            Write-Log "Could not find expected installer ($InstallerFileName) inside the ZIP!" -Level ERROR
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Failed" -Details "Installer missing from ZIP"
            return
        }

        # 4. Install
        Write-Log "Running Installer from extracted folder..."
        $msiArgs = "/i `"$installerPath`" " + ($InstallArgs -join " ")
        if ($InstallDirectory) { $msiArgs += " INSTALLDIR=`"$InstallDirectory`"" }
        
        $process = if ($installerPath.ToLower().EndsWith(".msi")) {
            Start-Process "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -ErrorAction Stop
        } else {
            Start-Process $installerPath -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop
        }

        # 5. Evaluate and Clean Up
        if ($process.ExitCode -in @(0, 3010)) {
            Write-Log "$SoftwareName installed successfully." -Level SUCCESS
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Success" -Details $(if ($process.ExitCode -eq 3010) {"Reboot Required"} else {"Success"})
            
            # Cleanup ZIP and Extracted Folder
            Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path $ExtractFolder -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            Write-Log "Installation failed. Code: $($process.ExitCode)." -Level ERROR
            Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Failed" -Details "Exit Code: $($process.ExitCode)"
        }
    } catch {
        Write-Log "Error: $($_.Exception.Message)" -Level ERROR
        Record-TaskStatus -TaskName "Install: $SoftwareName" -Status "Failed" -Details "Exception Occurred"
    }
}

# --- 6. Execution Blocks ---

# A. FIPS Compliance
Write-Log "`n--- FIPS Compliance Check ---"
if (-not (Get-FipsRegistryStatus)) {
    Write-Log "FIPS disabled. Enabling in registry..."
    New-Item -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name "Enabled" -Value 1 -Force
    Record-TaskStatus -TaskName "FIPS Compliance" -Status "Success" -Details "Enabled (Reboot Required)"
} else {
    Write-Log "FIPS is already enabled." -Level SUCCESS
    Record-TaskStatus -TaskName "FIPS Compliance" -Status "Skipped" -Details "Already Enabled"
}

# B. Software Installations
Write-Log "`n--- Software Installation Phase ---"

Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/CR13SP27MSI32_0-10010309.MSI?sp=racw&st=2026-02-27T09:23:31Z&se=2031-02-27T17:38:31Z&spr=https&sv=2024-11-04&sr=b&sig=6YdH%2BnpKFIi0REqIqnsexIyqJcZF7bWhYatNtMlE2f4%3D" -DestinationPath "$tempInstallPath\CR13SP27MSI32.msi" -SoftwareName "SAP Crystal Reports (32-bit)" -UninstallDisplayName "SAP Crystal Reports runtime engine for .NET Framework (32-bit)"
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/CR13SP27MSI64_0-10010309.MSI?sp=racw&st=2026-02-27T09:24:20Z&se=2031-02-27T17:39:20Z&spr=https&sv=2024-11-04&sr=b&sig=cootR9ALUq259FgQYpEg5VjQ1UBnz6RHftbTd6ZEJOk%3D" -DestinationPath "$tempInstallPath\CR13SP27MSI64.msi" -SoftwareName "SAP Crystal Reports (64-bit)" -UninstallDisplayName "SAP Crystal Reports runtime engine for .NET Framework (64-bit)"

# --- NEW: ZIPPED Phoenix Managers ---
# IMPORTANT: Ensure the -InstallerFileName exactly matches the name of the MSI inside the ZIP file!
Install-ZippedPackage -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/Phoenix%20Server%20Application%20Manager%202024%20-%20FIPS.zip?sp=racw&st=2026-02-27T09:27:17Z&se=2031-02-27T17:42:17Z&spr=https&sv=2024-11-04&sr=b&sig=GEfnpeBEBgmWhaetS14kgaDbdWhIgSLUC%2FtbzmhjLA8%3D" `
    -ZipPath "$phoenixAppManagerTempPath\PhoenixServer.zip" `
    -ExtractFolder "$phoenixAppManagerTempPath\PhoenixServerExtracted" `
    -InstallerFileName "PhoenixServerApplicationManager.msi" `
    -SoftwareName "Phoenix Server App Manager" `
    -UninstallDisplayName "Phoenix Server Application Manager" `
    -InstallDirectory "${phoenixAppManagerInstallDrive}:\Program Files (x86)\ProPhoenix\Server Application Manager"

Install-ZippedPackage -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/Phoenix%20Client%20Application%20Manager%202024%20FIPS.zip?sp=racw&st=2026-02-27T09:26:33Z&se=2031-02-27T17:41:33Z&spr=https&sv=2024-11-04&sr=b&sig=FxAf6Vwa0EHcwQrUGw5msSk5dwwN6z79emPPxe0ioik%3D" `
    -ZipPath "$phoenixAppManagerTempPath\PhoenixClient.zip" `
    -ExtractFolder "$phoenixAppManagerTempPath\PhoenixClientExtracted" `
    -InstallerFileName "PhoenixClientApplicationManager.msi" `
    -SoftwareName "Phoenix Client App Manager" `
    -UninstallDisplayName "Phoenix Client Application Manager" `
    -InstallDirectory "${phoenixAppManagerInstallDrive}:\Program Files (x86)\ProPhoenix\Client Application Manager"

Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/dotnet-hosting-8.0.4-win.exe?sp=racw&st=2026-02-27T09:31:47Z&se=2031-02-27T17:46:47Z&spr=https&sv=2024-11-04&sr=b&sig=IOFkMN%2FXnkSPJwu6g4TpYq3PEJvbRXrAfAAB9CsLGs0%3D" -DestinationPath "$tempInstallPath\dotnet-hosting.exe" -SoftwareName "ASP.NET Core 8.0 Hosting" -InstallArgs @("/install", "/quiet", "/norestart") -UninstallDisplayName "Microsoft ASP.NET Core 8.0"

$accessDbUrl = if ([Environment]::Is64BitOperatingSystem) { "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/accessdatabaseengine_X64.exe?sp=racw&st=2026-02-27T09:31:02Z&se=2031-02-27T17:46:02Z&spr=https&sv=2024-11-04&sr=b&sig=o59u4cO9EiPiKDFuklmql969kDJSwF3vdkA7zC8JeHw%3D" }
Install-Package -Url $accessDbUrl -DestinationPath "$tempInstallPath\accessdb.exe" -SoftwareName "Access Database Engine" -InstallArgs @("/quiet", "/norestart") -UninstallDisplayName "Microsoft Access database engine"

Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/SmartInspect-redist-3.3.0.10181.exe?sp=racw&st=2026-02-27T09:30:24Z&se=2031-02-27T17:45:24Z&spr=https&sv=2024-11-04&sr=b&sig=SHOlYfzuByqzueb6t8PBq2NAK5PYx8C%2BnA%2FMtYCHuOk%3D" -DestinationPath "$tempInstallPath\SmartInspect.exe" -SoftwareName "SmartInspect" -InstallArgs @("/silent") -UninstallDisplayName "SmartInspect"
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/MicrosoftEdgeWebView2RuntimeInstallerX64.exe?sp=racw&st=2026-02-27T09:25:43Z&se=2031-02-27T17:40:43Z&spr=https&sv=2024-11-04&sr=b&sig=XvBB8E02UxAqyz4DChoc0oeuIRtLtNehQYEPmbjfayU%3D" -DestinationPath "$tempInstallPath\WebView2.exe" -SoftwareName "Microsoft Edge WebView2 Runtime" -InstallArgs @("/silent", "/install") -UninstallDisplayName "Microsoft Edge WebView2 Runtime"
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/ReportViewer.msi?sp=racw&st=2026-02-27T09:28:16Z&se=2031-02-27T17:43:16Z&spr=https&sv=2024-11-04&sr=b&sig=VDZWUc0sIvMyE2DppDxuuCSvh6TlZTrhdiJ0C%2FXDiMs%3D" -DestinationPath "$tempInstallPath\ReportViewer.msi" -SoftwareName "Microsoft Report Viewer" -UninstallDisplayName "Microsoft Report Viewer Redistributable"
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/SQLSysClrTypes%2086.msi?sp=racw&st=2026-02-27T09:29:46Z&se=2031-02-27T17:44:46Z&spr=https&sv=2024-11-04&sr=b&sig=O6E2XCHkrlwLwVEAmM5a%2Be8gz3D%2BFZBswCpDNCEgyZ4%3D" -DestinationPath "$tempInstallPath\SQLSysClrTypes86.msi" -SoftwareName "SQL Sys CLR Types (x86)" -UninstallDisplayName "Microsoft SQL Server System CLR Types (x86)"
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/SQLSysClrTypes%2064.msi?sp=racw&st=2026-02-27T09:28:56Z&se=2031-02-27T17:43:56Z&spr=https&sv=2024-11-04&sr=b&sig=8w5Xqupkr2Et4A8lGo9d3aHjpZsi9VJ9dQ1lDwF7kJM%3D" -DestinationPath "$tempInstallPath\SQLSysClrTypes64.msi" -SoftwareName "SQL Sys CLR Types (x64)" -UninstallDisplayName "Microsoft SQL Server System CLR Types (x64)"

# --- FIXED: OLE DB Driver 1603 Error Fix ---
# Added IACCEPTMSOLEDBSQLLICENSETERMS=YES to bypass the fatal error
Install-Package -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/msoledbsql.msi?sp=racw&st=2026-02-27T09:32:21Z&se=2031-02-27T17:47:21Z&spr=https&sv=2024-11-04&sr=b&sig=MW6ExawS0YsZdjSO%2BOhY9ncYflrPgEona9aoqF3gn%2FU%3D" -DestinationPath "$tempInstallPath\msoledbsql.msi" -SoftwareName "OLE DB Driver for SQL" -InstallArgs @("/qn", "/norestart", "IACCEPTMSOLEDBSQLLICENSETERMS=YES") -UninstallDisplayName "Microsoft OLE DB Driver for SQL Server"


# C. Machine.config Optimization
Write-Log "`n--- Machine.config Optimization ---"
$numberOfCores = [Environment]::ProcessorCount

function Update-MachineConfig {
    param([string]$ConfigPath, [string]$BackupFolderPath, [string]$Label)
    try {
        if (!(Test-Path -path (Split-Path $ConfigPath))) { New-Item (Split-Path $ConfigPath) -Type Directory -Force | Out-Null }
        if (!(Test-Path -path $BackupFolderPath)) { New-Item $BackupFolderPath -Type Directory -Force | Out-Null }
        
        if (Test-Path $ConfigPath) { Copy-Item $ConfigPath -Destination $BackupFolderPath -Force } 
        else {
            $xmlText = "<?xml version=`"1.0`" encoding=`"utf-8`"?><configuration><system.web></system.web></configuration>"
            Set-Content -Path $ConfigPath -Value $xmlText -Encoding Ascii
        }

        [xml]$machineConfig = Get-Content $ConfigPath
        $sysWebNode = $machineConfig.SelectSingleNode("/configuration/system.web")
        $rootNode = $machineConfig.SelectSingleNode("/configuration")

        @("processModel", "httpRuntime") | ForEach-Object {
            $node = $sysWebNode.SelectSingleNode($_)
            if ($node) { $sysWebNode.RemoveChild($node) | Out-Null }
        }
        $sysNetNode = $rootNode.SelectSingleNode("system.net")
        if ($sysNetNode) { $rootNode.RemoveChild($sysNetNode) | Out-Null }

        $pModel = $machineConfig.CreateElement("processModel")
        $pModel.SetAttribute("autoConfig", "false")
        $pModel.SetAttribute("maxWorkerThreads", "100")
        $pModel.SetAttribute("maxIoThreads", "100")
        $pModel.SetAttribute("minWorkerThreads", "50")
        $pModel.SetAttribute("minIoThreads", "50")
        $sysWebNode.AppendChild($pModel) | Out-Null

        $hRuntime = $machineConfig.CreateElement("httpRuntime")
        $hRuntime.SetAttribute("minFreeThreads", (88 * $numberOfCores).ToString())
        $hRuntime.SetAttribute("minLocalRequestFreeThreads", (76 * $numberOfCores).ToString())
        $sysWebNode.AppendChild($hRuntime) | Out-Null

        $netXml = $machineConfig.CreateElement("system.net")
        $connMgmt = $machineConfig.CreateElement("connectionManagement")
        $addXml = $machineConfig.CreateElement("add")
        $addXml.SetAttribute("address", "*")
        $addXml.SetAttribute("maxconnection", (12 * $numberOfCores).ToString())
        $connMgmt.AppendChild($addXml) | Out-Null
        $netXml.AppendChild($connMgmt) | Out-Null
        $rootNode.AppendChild($netXml) | Out-Null

        $machineConfig.Save($ConfigPath)
        Record-TaskStatus -TaskName "Machine.config ($Label)" -Status "Success" -Details "Optimized for $numberOfCores Cores"
    } catch {
        Record-TaskStatus -TaskName "Machine.config ($Label)" -Status "Failed" -Details "XML Modification Error"
    }
}

Update-MachineConfig "C:\Windows\Microsoft.NET\Framework\v2.0.50727\Config\machine.config" "${backupDrive}:\PnxTemp\Machineconfig\32bit\V2" "v2 32-bit"
Update-MachineConfig "C:\Windows\Microsoft.NET\Framework64\v2.0.50727\Config\machine.config" "${backupDrive}:\PnxTemp\Machineconfig\64bit\V2" "v2 64-bit"
Update-MachineConfig "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Config\machine.config" "${backupDrive}:\PnxTemp\Machineconfig\32bit\V4" "v4 32-bit"
Update-MachineConfig "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\machine.config" "${backupDrive}:\PnxTemp\Machineconfig\64bit\V4" "v4 64-bit"

# D. Page File Safety Limits
Write-Log "`n--- Page File Configuration ---"
try {
    $totalMemGB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $calculatedSizeMB = [math]::Round(($totalMemGB / 2) + $totalMemGB) * 1024
    $initialSizeMB = if ($calculatedSizeMB -gt 32768) { 32768 } else { $calculatedSizeMB }
    $maximumSizeMB = $initialSizeMB + 64
    $desiredValueData = "C:\pagefile.sys $initialSizeMB $maximumSizeMB"

    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Value $desiredValueData -Force
    Record-TaskStatus -TaskName "Page File Setup" -Status "Success" -Details "Set to $initialSizeMB MB"
} catch {
    Record-TaskStatus -TaskName "Page File Setup" -Status "Failed" -Details "Could not update registry"
}

# E. Log Cleaner Task
Write-Log "`n--- IIS Log Cleaner Task ---"
$logCleanerZipUrl = "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Application-%202026/Prerequsite%20softwares/LogCleaner.zip?sp=racw&st=2026-02-27T09:24:58Z&se=2031-02-27T17:39:58Z&spr=https&sv=2024-11-04&sr=b&sig=f1sLM0MZcRaRtP9Zx8V0FfEHcO0Kpv88NOceFb50640%3D"
$taskDestPath = "${installDrive}:\ProPhoenix\Tools\LogCleaner"
$zipDest = "$tempInstallPath\LogCleaner.zip"

if (-not (Test-Path $taskDestPath)) { New-Item $taskDestPath -ItemType Directory -Force | Out-Null }

try {
    Invoke-WebRequest -Uri $logCleanerZipUrl -OutFile $zipDest -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $zipDest -DestinationPath $taskDestPath -Force
    Remove-Item $zipDest -Force -ErrorAction SilentlyContinue | Out-Null

    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$taskDestPath\CleanLogs.bat`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "4:00 AM"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

    Register-ScheduledTask -TaskName "Clean Logs in IIS" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "IIS Log Cleaner" -Force | Out-Null
    Record-TaskStatus -TaskName "Log Cleaner Task" -Status "Success" -Details "Task Registered"
} catch {
    Record-TaskStatus -TaskName "Log Cleaner Task" -Status "Failed" -Details "Setup Error"
}

# F. Firewall Ports
Write-Log "`n--- Firewall Configuration ---"
$requiredPorts = @(80, 443, 8888, 8889, 8080, 6666, 6667, 8245, 7005, 6990, 9998, 8090, 3000, 5555, 9600, 1433, 8081, 8182, 8181)
$fwStatus = @{ Created = 0; Exists = 0; Failed = 0 }

foreach ($port in $requiredPorts) {
    foreach ($dir in @("Inbound", "Outbound")) {
        $ruleName = "ProPhoenix Port $port ($dir)"
        
        if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
            Write-Log "Rule already exists: $ruleName" -Level INFO
            $fwStatus.Exists++
        } else {
            try {
                Write-Log "Creating missing rule: $ruleName" -Level WARNING
                New-NetFirewallRule -DisplayName $ruleName -Direction $dir -Action Allow -Protocol TCP -LocalPort $port -Profile Any -ErrorAction Stop | Out-Null
                $fwStatus.Created++
            } catch {
                Write-Log "Failed to create rule: $ruleName" -Level ERROR
                $fwStatus.Failed++
            }
        }
    }
}
Record-TaskStatus -TaskName "Firewall Rules" -Status "Completed" -Details "Created: $($fwStatus.Created), Existed: $($fwStatus.Exists), Failed: $($fwStatus.Failed)"


# G. Windows Update Policy
Write-Log "`n--- Windows Update Policy ---"
try {
    $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (!(Test-Path $auPath)) { New-Item $auPath -Force | Out-Null }
    Set-ItemProperty -Path $auPath -Name "AUOptions" -Value 3 -Force
    Remove-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Force -ErrorAction SilentlyContinue | Out-Null

    & gpupdate /force | Out-Null
    Restart-Service -Name wuauserv -Force -ErrorAction SilentlyContinue | Out-Null
    Record-TaskStatus -TaskName "Windows Update" -Status "Success" -Details "Set to Download Only"
} catch {
    Record-TaskStatus -TaskName "Windows Update" -Status "Failed" -Details "Policy Error"
}

# --- 7. Final Status Report ---
Write-Host "`n=========================================================================" -ForegroundColor Cyan
Write-Host "                       FINAL EXECUTION SUMMARY                           " -ForegroundColor Cyan
Write-Host "=========================================================================`n" -ForegroundColor Cyan

foreach ($task in $global:ExecutionSummary) {
    $color = switch ($task.Status) {
        "Success"   { "Green" }
        "Completed" { "Green" }
        "Skipped"   { "DarkYellow" }
        "Failed"    { "Red" }
        default     { "White" }
    }
    
    $paddedTask = $task.Task.PadRight(35)
    $paddedStatus = $task.Status.PadRight(10)
    Write-Host "$paddedTask | $paddedStatus | $($task.Details)" -ForegroundColor $color
}

Write-Host "`n=========================================================================" -ForegroundColor Cyan
Write-Host "A system reboot is highly recommended to finalize configurations." -ForegroundColor Cyan