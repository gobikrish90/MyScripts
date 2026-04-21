# Ensure Admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Please run PowerShell as Administrator."
    exit
}

# Global variable for log file path
$script:LogFilePath = ""

# Function to write messages to console and log file
Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO", # INFO, WARNING, ERROR
        [switch]$NoConsole # Do not write to console
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to log file if path is set
    if (-not [string]::IsNullOrEmpty($script:LogFilePath)) {
        try {
            Add-Content -Path $script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {
            # Fallback if cannot write to log file, but still try to write to console
            Write-Host "WARNING: Could not write to log file: $($_.Exception.Message) - Log entry: $logEntry" -ForegroundColor Red
        }
    }

    # Write to console with color based on level
    if (-not $NoConsole) {
        switch ($Level) {
            "INFO" { Write-Host $logEntry -ForegroundColor White }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            default { Write-Host $logEntry -ForegroundColor Gray }
        }
    }
}

Function Get-FipsRegistryStatus {
    try {
        $fipsEnabled = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name "Enabled" -ErrorAction Stop).Enabled
        if ($fipsEnabled -eq 1) {
            Write-Log "Current FIPS Registry Status: ENABLED"
            return $true
        } else {
            Write-Log "Current FIPS Registry Status: DISABLED"
            return $false
        }
    }
    catch {
        Write-Log ("Current FIPS Registry Status Check Failed: {0}" -f $_.Exception.Message) -Level ERROR
        Write-Error ("Current FIPS Registry Status Check Failed: {0}" -f $_.Exception.Message)
        return $false
    }
}

Function Set-FipsRegistryEnabled {
    Write-Log "Attempting to set FIPS to ENABLED in the registry..."

    try {
        # Create the FipsAlgorithmPolicy key if it doesn't exist (silently if it does)
        New-Item -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Force -ErrorAction SilentlyContinue | Out-Null

        # Set the 'Enabled' property to 1
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name "Enabled" -Value 1 -Force -ErrorAction Stop

        Write-Log "FIPS has been successfully set to ENABLED in the registry."
        return $true
    }
    catch {
        Write-Log ("Failed to set FIPS in the registry: {0}" -f $_.Exception.Message) -Level ERROR
        Write-Error ("Failed to set FIPS in the registry: {0}" -f $_.Exception.Message)
        return $false
    }
}

# --- Main Script Logic ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  FIPS Compliance Check" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Prompt the user to enter the desired drive letter for software installations.
$installDrive = Read-Host "Please enter the drive letter for general software installations (e.g., C)"
# Validate the input for install drive. Basic check for a single letter.
if ($installDrive -notmatch "^[A-Za-z]$") {
    Write-Host "Invalid drive letter entered for general installations. Please enter a single letter (e.g., C)." -ForegroundColor Red
    exit 1
}

# Set the log file path based on the selected install drive immediately after validation
$script:LogFilePath = "${installDrive}:\PnxTemp\script_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Write-Log "Log file will be created at: $script:LogFilePath"

# Create the temporary directory for downloads on the specified install drive
$tempInstallPath = "${installDrive}:\PnxTemp"
if (!(Test-Path -Path $tempInstallPath)) {
    Write-Log "Temporary installation directory: $tempInstallPath does NOT exist. Creating it now."
    New-Item -Path $tempInstallPath -ItemType Directory -Force | Out-Null
} else {
    Write-Log "Temporary installation directory: $tempInstallPath already exists."
}

# Now perform the FIPS check and subsequent operations, which will be logged.
Write-Log "Checking FIPS status..."

$currentFipsStatus = Get-FipsRegistryStatus

if (-not $currentFipsStatus) {
    Write-Log "`nFIPS is currently disabled. Proceeding to set registry key..."
    $enabledSuccessfully = Set-FipsRegistryEnabled

    if ($enabledSuccessfully) {
        Write-Log "`nWARNING: FIPS mode is now set in the registry, but a REBOOT is REQUIRED for full system-wide enforcement and application compatibility." -Level WARNING
        Write-Log "          Applications and services may not fully adhere to FIPS until after a restart." -Level WARNING
        Write-Log "Please plan for a system reboot at your earliest convenience."
        Write-Host "`nWARNING: FIPS mode is now set in the registry, but a REBOOT is REQUIRED for full system-wide enforcement and application compatibility." -ForegroundColor Yellow
        Write-Host "          Applications and services may not fully adhere to FIPS until after a restart." -ForegroundColor Yellow
        Write-Host "Please plan for a system reboot at your earliest convenience." -ForegroundColor Cyan
    }
} else {
    Write-Log "`nFIPS is already enabled in the registry. No action needed."
    Write-Host "`nFIPS is already enabled in the registry. No action needed." -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  Software Installation Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Log "`n==========================================" -NoConsole
Write-Log "  Software Installation Configuration" -NoConsole
Write-Log "==========================================" -NoConsole

# Define a helper function for downloading and installing MSI/EXE packages
Function Download-And-Install {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,
        [Parameter(Mandatory=$true)]
        [string]$SoftwareName,
        [string[]]$InstallArgs = @("/passive", "/norestart", "/qn"), # Default silent install arguments for MSI and many EXEs
        [Parameter(Mandatory=$false)]
        [string]$UninstallDisplayName, # Optional: Display name to check in Uninstall registry key
        [Parameter(Mandatory=$false)]
        [string]$InstallDirectory # Optional: Specific installation directory for MSI
    )

    Write-Log "`nAttempting to process: $SoftwareName"
    Write-Host "`nAttempting to process: $SoftwareName" -ForegroundColor Cyan

    # Check if software is already installed (basic check by DisplayName)
    if ($UninstallDisplayName) {
        Write-Log "Checking for existing installation of '$SoftwareName' (looking for '$UninstallDisplayName' in registry)..."
        Write-Host "Checking for existing installation of '$SoftwareName' (looking for '$UninstallDisplayName' in registry)..."
        $isInstalled = $false
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($path in $uninstallPaths) {
            try {
                $foundSoftware = Get-ItemProperty -Path "$path\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$UninstallDisplayName*" }
                if ($foundSoftware) {
                    Write-Log "$SoftwareName is already installed (found matching DisplayName: '$($foundSoftware.DisplayName)' in registry path: '$path'). Skipping installation."
                    Write-Host "$SoftwareName is already installed (found matching DisplayName: '$($foundSoftware.DisplayName)' in registry path: '$path'). Skipping installation." -ForegroundColor Green
                    $isInstalled = $true
                    break
                }
            } catch {
                Write-Log "No matching entries found or error accessing '$path': $($_.Exception.Message)" -Level WARNING
                Write-Host "No matching entries found or error accessing '$path': $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        }
        if ($isInstalled) {
            return # Exit function if already installed
        } else {
            Write-Log "No existing installation of '$SoftwareName' found matching '$UninstallDisplayName'. Proceeding with installation." -Level WARNING
            Write-Host "No existing installation of '$SoftwareName' found matching '$UninstallDisplayName'. Proceeding with installation." -ForegroundColor Yellow
        }
    } else {
        Write-Log "UninstallDisplayName not provided for '$SoftwareName'. Skipping pre-installation check and proceeding with installation." -Level WARNING
        Write-Host "UninstallDisplayName not provided for '$SoftwareName'. Skipping pre-installation check and proceeding with installation." -ForegroundColor Yellow
    }

    try {
        # Ensure the destination directory exists
        $destinationDir = Split-Path -Parent $DestinationPath
        if (-not (Test-Path $destinationDir)) {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
        }

        # Download the file
        Write-Log "Downloading $SoftwareName from $Url to $DestinationPath..."
        Write-Host "Downloading $SoftwareName from $Url to $DestinationPath..."
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Download of $SoftwareName completed successfully."
        Write-Host "Download of $SoftwareName completed successfully." -ForegroundColor Green

        # Add a short delay to ensure file handle is released
        Start-Sleep -Seconds 2
        Write-Log "Proceeding with installation after a short delay."
        Write-Host "Proceeding with installation after a short delay."

        # Install the software
        Write-Log "Installing $SoftwareName..."
        Write-Host "Installing $SoftwareName..."
        # Check if it's an MSI or EXE to use appropriate install command
        if ($DestinationPath.ToLower().EndsWith(".msi")) {
            $msiArgs = "/i `"$DestinationPath`" $InstallArgs"
            if ($InstallDirectory) {
                $msiArgs += " INSTALLDIR=`"$InstallDirectory`""
                Write-Log "Attempting to install MSI to: $InstallDirectory" -Level WARNING
                Write-Host "Attempting to install MSI to: $InstallDirectory" -ForegroundColor DarkYellow
            }
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -ErrorAction Stop
        } else { # Assume EXE
            $process = Start-Process -FilePath $DestinationPath -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop
        }

        if ($process.ExitCode -eq 0) {
            Write-Log "$SoftwareName installed successfully."
            Write-Host "$SoftwareName installed successfully." -ForegroundColor Green
        } else {
            Write-Log "Installation of $SoftwareName failed with exit code $($process.ExitCode)." -Level ERROR
            Write-Error "Installation of $SoftwareName failed with exit code $($process.ExitCode)."
        }
    }
    catch {
        Write-Log ("Failed to download or install {0}: {1}" -f $SoftwareName, $_.Exception.Message) -Level ERROR
        Write-Error ("Failed to download or install {0}: {1}" -f $SoftwareName, $_.Exception.Message)
    }
}

# New function to download and extract a ZIP file
Function Download-And-ExtractZip {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$ZipDestinationPath,
        [Parameter(Mandatory=$true)]
        [string]$ExtractPath,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    Write-Log "`nAttempting to download and extract: $FileName"
    Write-Host "`nAttempting to download and extract: $FileName" -ForegroundColor Cyan

    try {
        # Ensure the destination directory for the zip exists
        $zipDir = Split-Path -Parent $ZipDestinationPath
        if (-not (Test-Path $zipDir)) {
            New-Item -Path $zipDir -ItemType Directory -Force | Out-Null
        }

        Write-Log "Downloading $FileName from $Url to $ZipDestinationPath..."
        Write-Host "Downloading $FileName from $Url to $ZipDestinationPath..."
        Invoke-WebRequest -Uri $Url -OutFile $ZipDestinationPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Download of $FileName completed successfully."
        Write-Host "Download of $FileName completed successfully." -ForegroundColor Green

        # Add a short delay to ensure file handle is released
        Start-Sleep -Seconds 2
        Write-Log "Proceeding with extraction after a short delay."
        Write-Host "Proceeding with extraction after a short delay."

        Write-Log "Extracting $FileName to $ExtractPath..."
        Write-Host "Extracting $FileName to $ExtractPath..."
        Expand-Archive -Path $ZipDestinationPath -DestinationPath $ExtractPath -Force
        Write-Log "Extraction of $FileName completed successfully."
        Write-Host "Extraction of $FileName completed successfully." -ForegroundColor Green

        # Optionally, remove the downloaded ZIP file after extraction
        Remove-Item -Path $ZipDestinationPath -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Removed temporary ZIP file: $ZipDestinationPath" -Level WARNING
        Write-Host "Removed temporary ZIP file: $ZipDestinationPath" -ForegroundColor DarkYellow

    } catch {
        Write-Log ("Failed to download or extract {0}: {1}" -f $FileName, $_.Exception.Message) -Level ERROR
        Write-Error ("Failed to download or extract {0}: {1}" -f $FileName, $_.Exception.Message)
    }
}

# New helper: install MSI from ZIP (for Phoenix Application Managers)
Function Install-MsiFromZip {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipUrl,

        [Parameter(Mandatory = $true)]
        [string]$TempFolder,

        [Parameter(Mandatory = $true)]
        [string]$ProductName,            # Used for folder/zip name & logging

        [Parameter(Mandatory = $false)]
        [string]$InstallDirectory,       # Optional INSTALLDIR

        [Parameter(Mandatory = $false)]
        [string]$UninstallDisplayName    # Optional DisplayName for pre-check
    )

    Write-Log "`n--- Processing: $ProductName ---"
    Write-Host "`n--- Processing: $ProductName ---" -ForegroundColor Cyan

    # 1. Check if software is already installed
    if ($UninstallDisplayName) {
        Write-Log "Checking for existing installation of '$ProductName' (DisplayName like '*$UninstallDisplayName*')..."
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )

        foreach ($path in $uninstallPaths) {
            try {
                $foundSoftware = Get-ItemProperty -Path "$path\*" -ErrorAction SilentlyContinue |
                                 Where-Object { $_.DisplayName -like "*$UninstallDisplayName*" }

                if ($foundSoftware) {
                    Write-Log "$ProductName is already installed (found '$($foundSoftware.DisplayName)' in '$path'). Skipping installation."
                    Write-Host "$ProductName is already installed. Skipping installation." -ForegroundColor Green
                    return
                }
            } catch {
                Write-Log "Error checking '$path' for '$ProductName': $($_.Exception.Message)" -Level WARNING
            }
        }

        Write-Log "No existing installation of '$ProductName' found. Proceeding with installation." -Level WARNING
        Write-Host "No existing installation of '$ProductName' found. Proceeding with installation." -ForegroundColor Yellow
    }

    # 2. Prepare paths
    if (!(Test-Path -Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory -Force | Out-Null
    }

    $zipPath      = Join-Path $TempFolder "$ProductName.zip"
    $extractPath  = Join-Path $TempFolder $ProductName

    # 3. Download + extract ZIP
    Download-And-ExtractZip `
        -Url $ZipUrl `
        -ZipDestinationPath $zipPath `
        -ExtractPath $extractPath `
        -FileName "$ProductName.zip"

    # 4. Locate MSI in extracted folder
    Write-Log "Searching for MSI inside '$extractPath'..."
    $msiFile = Get-ChildItem -Path $extractPath -Filter '*.msi' -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1

    if (-not $msiFile) {
        Write-Log "No MSI file found in '$extractPath' for $ProductName." -Level ERROR
        Write-Error "No MSI file found in '$extractPath' for $ProductName."
        return
    }

Write-Log ("Found MSI for {0}: {1}" -f $ProductName, $msiFile.FullName)
Write-Host ("Found MSI for {0}: {1}" -f $ProductName, $msiFile.FullName) -ForegroundColor Cyan

    # 5. Install MSI
    try {
        Write-Log "Installing $ProductName..."
        $msiArgs = "/i `"$($msiFile.FullName)`" /qn /norestart"

        if ($InstallDirectory) {
            Write-Log "Installing $ProductName to custom directory: $InstallDirectory" -Level WARNING
            $msiArgs += " INSTALLDIR=`"$InstallDirectory`""
        }

        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -ErrorAction Stop

        if ($process.ExitCode -eq 0) {
            Write-Log "$ProductName installed successfully."
            Write-Host "$ProductName installed successfully." -ForegroundColor Green
        } else {
            Write-Log "Installation of $ProductName failed with exit code $($process.ExitCode)." -Level ERROR
            Write-Error "Installation of $ProductName failed with exit code $($process.ExitCode)."
        }
    } catch {
        Write-Log ("Failed to install {0} from MSI: {1}" -f $ProductName, $_.Exception.Message) -Level ERROR
        Write-Error ("Failed to install {0} from MSI: {1}" -f $ProductName, $_.Exception.Message)
    }
}

# Crystal Reports Runtime (32-bit and 64-bit)
Write-Log "`n--- Installing Crystal Reports Runtimes ---"
Write-Host "`n--- Installing Crystal Reports Runtimes ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Software/CR13SP27MSI32_0-10010309.MSI?sp=rw&st=2025-11-17T14:38:41Z&se=2026-11-16T22:53:41Z&spr=https&sv=2024-11-04&sr=b&sig=O2ZuPGcteY8%2FVOJy%2Fhq15aOPwukvJmE79G0AHbzW7kc%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\CR13SP27MSI32_0-10010309.MSI" `
    -SoftwareName "SAP Crystal Reports runtime engine for .NET Framework (32-bit)" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "SAP Crystal Reports runtime engine for .NET Framework (32-bit)"

Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Pre-requsite%20Software/CR13SP27MSI64_0-10010309.MSI?sp=rw&st=2025-11-17T14:39:29Z&se=2026-11-16T22:54:29Z&spr=https&sv=2024-11-04&sr=b&sig=eZ4KwH2Z0%2FWO4GZoUMleCjBWVE8Doa5k8Z4qFu2Qscs%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\CR13SP27MSI64_0-10010309.MSI" `
    -SoftwareName "SAP Crystal Reports runtime engine for .NET Framework (64-bit)" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "SAP Crystal Reports runtime engine for .NET Framework (64-bit)"

# Phoenix Application Managers
Write-Log "`n--- Installing Phoenix Application Managers (New Versions) ---"
Write-Host "`n--- Installing Phoenix Application Managers (New Versions) ---" -ForegroundColor DarkCyan

# Single prompt for Phoenix Application Managers install drive
$phoenixAppManagerInstallDrive = Read-Host "Please enter the drive letter for Phoenix Application Manager installations (Server and Client, e.g., C)"
if ($phoenixAppManagerInstallDrive -notmatch "^[A-Za-z]$") {
    Write-Log "Invalid drive letter entered for Phoenix Application Managers. Please enter a single letter (e.g., C)." -Level ERROR
    Write-Error "Invalid drive letter entered for Phoenix Application Managers. Please enter a single letter (e.g., C)."
    exit 1
}

$phoenixAppManagerTempPath = "${phoenixAppManagerInstallDrive}:\PnxTemp" # Temp path for download
if (!(Test-Path -Path $phoenixAppManagerTempPath)) {
    Write-Log "Temporary installation directory for Phoenix Application Managers: $phoenixAppManagerTempPath does NOT exist. Creating it now."
    New-Item -Path $phoenixAppManagerTempPath -ItemType Directory -Force | Out-Null
} else {
    Write-Log "Temporary installation directory for Phoenix Application Managers: $phoenixAppManagerTempPath already exists."
}

# Server Application Manager (ZIP -> Extract -> MSI)
Install-MsiFromZip `
    -ZipUrl "https://produpdates.blob.core.windows.net/web-config/PhoenixServerApplicationManager.zip?sp=racw&st=2025-11-26T13:55:37Z&se=2027-01-14T22:10:37Z&spr=https&sv=2024-11-04&sr=b&sig=jWQdbvBpelrL4EGX7oYarsXX8b4TZFXwjxPX3V3YkCE%3D" `
    -TempFolder $phoenixAppManagerTempPath `
    -ProductName "PhoenixServerApplicationManager" `
    -InstallDirectory "${phoenixAppManagerInstallDrive}:\Program Files (x86)\ProPhoenix\Server Application Manager" `
    -UninstallDisplayName "Server Application Manager"

# Client Application Manager (ZIP -> Extract -> MSI)
Install-MsiFromZip `
    -ZipUrl "https://produpdates.blob.core.windows.net/web-config/PhoenixClientApplicationManager.zip?sp=racw&st=2025-11-26T13:56:29Z&se=2027-02-09T22:11:29Z&spr=https&sv=2024-11-04&sr=b&sig=5aH3G9Ghhk7RAVDu%2BPFCT%2FHwqAlUvZPAB7t0Is1kmCI%3D" `
    -TempFolder $phoenixAppManagerTempPath `
    -ProductName "PhoenixClientApplicationManager" `
    -InstallDirectory "${phoenixAppManagerInstallDrive}:\Program Files (x86)\ProPhoenix\Client Application Manager" `
    -UninstallDisplayName "Client Application Manager"

# Adobe Reader 11
Write-Log "`n--- Installing Adobe Reader 11 ---"
Write-Host "`n--- Installing Adobe Reader 11 ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web-config/AdbeRdr11000_en_US.msi?sp=racw&st=2025-12-03T15:23:46Z&se=2027-07-14T23:38:46Z&spr=https&sv=2024-11-04&sr=b&sig=bLBGcjhjw%2BW%2FXBc6eAHC%2Bmc41rIbgtamSyO0D6g8kEU%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\AdbeRdr11000_en_US.msi" `
    -SoftwareName "Adobe Reader XI" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "Adobe Reader XI"

# .NET Hosting 8.0.4
Write-Log "`n--- Installing .NET Hosting 8.0.4 ---"
Write-Host "`n--- Installing .NET Hosting 8.0.4 ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://download.visualstudio.microsoft.com/download/pr/00397fee-1bd9-44ef-899b-4504b26e6e96/ab9c73409659f3238d33faee304a8b7c/dotnet-hosting-8.0.4-win.exe" `
    -DestinationPath "${installDrive}:\PnxTemp\dotnet-hosting.exe" `
    -SoftwareName "Microsoft ASP.NET Core 8.0" `
    -InstallArgs @("/install", "/quiet", "/norestart") `
    -UninstallDisplayName "Microsoft ASP.NET Core 8.0"

# Access Database Engine
Write-Log "`n--- Installing Access Database Engine ---"
Write-Host "`n--- Installing Access Database Engine ---" -ForegroundColor DarkCyan
$accessDatabaseEngineUrl = if ([Environment]::Is64BitOperatingSystem) {
    "https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/accessdatabaseengine_X64.exe"
} else {
    "https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/accessdatabaseengine.exe"
}
Download-And-Install `
    -Url $accessDatabaseEngineUrl `
    -DestinationPath "${installDrive}:\PnxTemp\accessdb.exe" `
    -SoftwareName "Microsoft Access database engine" `
    -InstallArgs @("/quiet", "/norestart") `
    -UninstallDisplayName "Microsoft Access database engine"

# SmartInspect
Write-Log "`n--- Installing SmartInspect ---"
Write-Host "`n--- Installing SmartInspect ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web-config/SmartInspect-redist-3.3.0.10181.exe?sp=racw&st=2025-12-03T15:24:41Z&se=2027-06-15T23:39:41Z&spr=https&sv=2024-11-04&sr=b&sig=VQozur8Oaf5piUQNedZN%2BPs8xchB6SD6i9yjczeyORQ%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\SmartInspect-redist-3.3.0.10181.exe" `
    -SoftwareName "SmartInspect" `
    -InstallArgs @("/silent") `
    -UninstallDisplayName "SmartInspect"

# Microsoft Edge WebView2 Runtime
Write-Log "`n--- Installing Microsoft Edge WebView2 Runtime ---"
Write-Host "`n--- Installing Microsoft Edge WebView2 Runtime ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/MicrosoftEdgeWebView2RuntimeInstallerX64%20(3).exe?sp=rw&st=2025-11-17T14:18:38Z&se=2026-11-16T22:33:38Z&spr=https&sv=2024-11-04&sr=b&sig=GDbA6QniDxsnl6H260iGjH9i2aaJ5yoQoPU7PIL4lAc%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\MicrosoftEdgeWebView2RuntimeInstallerX64.exe" `
    -SoftwareName "Microsoft Edge WebView2 Runtime" `
    -InstallArgs @("/silent", "/install") `
    -UninstallDisplayName "Microsoft Edge WebView2 Runtime"

# SQLSysClrTypes 86
Write-Log "`n--- Installing Microsoft SQL Server System CLR Types (x86) ---"
Write-Host "`n--- Installing Microsoft SQL Server System CLR Types (x86) ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/SQLSysClrTypes%2086.msi?sp=rw&st=2025-11-17T14:23:03Z&se=2026-11-16T22:38:03Z&spr=https&sv=2024-11-04&sr=b&sig=MS8e5nsbI%2B%2B0iPCWUhuXGjNzwxFOpb5oQMVjq9PYwf8%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\SQLSysClrTypes86.msi" `
    -SoftwareName "Microsoft SQL Server System CLR Types (x86)" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "Microsoft SQL Server System CLR Types (x86)"

# SQLSysClrTypes 64
Write-Log "`n--- Installing Microsoft SQL Server System CLR Types (x64) ---"
Write-Host "`n--- Installing Microsoft SQL Server System CLR Types (x64) ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/SQLSysClrTypes%2064.msi?sp=r&st=2025-11-17T14:22:25Z&se=2026-11-16T22:37:25Z&spr=https&sv=2024-11-04&sr=b&sig=D8hMj3ldj%2F%2FFUWKHA2X4gUTv4qCnaLps2nB4znSQR5M%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\SQLSysClrTypes64.msi" `
    -SoftwareName "Microsoft SQL Server System CLR Types (x64)" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "Microsoft SQL Server System CLR Types (x64)"

# Microsoft Report Viewer (after SQLSysClrTypes)
Write-Log "`n--- Installing Microsoft Report Viewer ---"
Write-Host "`n--- Installing Microsoft Report Viewer ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/ReportViewer.msi?sp=r&st=2025-11-17T14:21:54Z&se=2026-11-16T22:36:54Z&spr=https&sv=2024-11-04&sr=b&sig=mPUr%2BPDXuZ5MUKUjhRWqTpf3dmswy7uTFTLwamPl3Eg%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\ReportViewer.msi" `
    -SoftwareName "Microsoft Report Viewer Redistributable" `
    -InstallArgs @("/qn", "/norestart") `
    -UninstallDisplayName "Microsoft Report Viewer Redistributable"

# Microsoft OLE DB Driver for SQL Server
Write-Log "`n--- Installing Microsoft OLE DB Driver for SQL Server ---"
Write-Host "`n--- Installing Microsoft OLE DB Driver for SQL Server ---" -ForegroundColor DarkCyan
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/msoledbsql-1.msi?sp=r&st=2025-11-17T14:23:35Z&se=2026-11-16T22:38:35Z&spr=https&sv=2024-11-04&sr=b&sig=%2BrtuJOEO4UPJ0hx%2BBb3mV1oleI4gUu1vqnfwhnZj6Tw%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\msoledbsql.msi" `
    -SoftwareName "Microsoft OLE DB Driver for SQL Server" `
    -InstallArgs @("/qn", "/norestart", "IACCEPTMSOLEDBSQLLICENSETERMS=YES") `
    -UninstallDisplayName "Microsoft OLE DB Driver for SQL Server"


# Microsoft OLE DB Driver for SQL Server
Write-Log "`n--- Installing Microsoft OLE DB Driver for SQL Server ---"
Write-Host "`n--- Installing Microsoft OLE DB Driver for SQL Server ---" -ForegroundColor DarkCyan

# NOTE: OLE DB MSI requires explicit license acceptance:
#   IACCEPTMSOLEDBSQLLICENSETERMS=YES
Download-And-Install `
    -Url "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/msoledbsql-1.msi?sp=r&st=2025-11-17T14:23:35Z&se=2026-11-16T22:38:35Z&spr=https&sv=2024-11-04&sr=b&sig=%2BrtuJOEO4UPJ0hx%2BBb3mV1oleI4gUu1vqnfwhnZj6Tw%3D" `
    -DestinationPath "${installDrive}:\PnxTemp\msoledbsql.msi" `
    -SoftwareName "Microsoft OLE DB Driver for SQL Server" `
    -InstallArgs @("/qn", "/norestart", "IACCEPTMSOLEDBSQLLICENSETERMS=YES") `
    -UninstallDisplayName "Microsoft OLE DB Driver for SQL Server"

# --- Machine.config Optimization ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  Machine.config Optimization" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Get number of CPU cores
$numberOfCores = [Environment]::ProcessorCount
Write-Host "Detected $numberOfCores logical CPU cores."

# Prompt the user to enter the desired drive letter for backups.
$backupDrive = Read-Host "Please enter the drive letter for the machine.config backups (e.g., D)"
if ($backupDrive -notmatch "^[A-Za-z]$") {
    Write-Error "Invalid drive letter entered for backups. Please enter a single letter (e.g., D)."
    exit 1
}

# Define Paths and Backup Folders for All Target Configurations
$pathV2_32bit = "C:\Windows\Microsoft.NET\Framework\v2.0.50727\Config\machine.config"
$backupfolderV2_32bit = "${backupDrive}:\PnxTemp\Machineconfig\32bit\V2"

$pathV2_64bit = "C:\Windows\Microsoft.NET\Framework64\v2.0.50727\Config\machine.config"
$backupfolderV2_64bit = "${backupDrive}:\PnxTemp\Machineconfig\64bit\V2"

$pathV4_32bit = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Config\machine.config"
$backupfolderV4_32bit = "${backupDrive}:\PnxTemp\Machineconfig\32bit\V4"

$pathV4_64bit = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\machine.config"
$backupfolderV4_64bit = "${backupDrive}:\PnxTemp\Machineconfig\64bit\V4"

function Update-MachineConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,         # The full path to the machine.config file to be updated

        [Parameter(Mandatory=$true)]
        [string]$BackupFolderPath    # The full path to the specific backup folder for this config file
    )

    Write-Host "`n--- Processing: $ConfigPath ---" -ForegroundColor Cyan

    # Ensure directory exists
    $configDirectory = Split-Path -Parent $ConfigPath
    if (!(Test-Path -path $configDirectory)) {
        Write-Host "Directory '$configDirectory' for machine.config not found. Creating it now."
        New-Item $configDirectory -Type Directory -Force | Out-Null
    }

    # Backup folder
    if (!(Test-Path -path $BackupFolderPath)) {
        Write-Host "Backup folder '$BackupFolderPath' does not exist. Creating it now."
        New-Item $BackupFolderPath -Type Directory | Out-Null
    } else {
        Write-Host "Backup folder '$BackupFolderPath' already exists."
    }

    if (Test-Path -path $ConfigPath) {
        try {
            Write-Host "Backing up existing '$ConfigPath' to '$BackupFolderPath'..."
            Copy-Item $ConfigPath -Destination $BackupFolderPath -Force
            Write-Host "Backup completed successfully." -ForegroundColor Green
        } catch {
            Write-Error ("Failed to backup {0}. Error: {1}" -f $ConfigPath, $_.Exception.Message)
        }
    } else {
        Write-Host "No existing machine.config found at '$ConfigPath'. A new one will be created."
    }

    [xml]$machineConfig = $null

    if (!(Test-Path -path $ConfigPath)) {
        Write-Host "Creating a new basic machine.config file at '$ConfigPath'..."
        $machineConfig = [System.Xml.XmlDocument]::new()
        $declaration = $machineConfig.CreateXmlDeclaration("1.0", "utf-8", $null)
        $machineConfig.AppendChild($declaration) | Out-Null
        $rootElement = $machineConfig.CreateElement("configuration")
        $machineConfig.AppendChild($rootElement) | Out-Null
        $systemWebElement = $machineConfig.CreateElement("system.web")
        $rootElement.AppendChild($systemWebElement) | Out-Null
        Write-Host "Basic machine.config structure created in memory."
    } else {
        Write-Host "Loading machine.config from '$ConfigPath'..."
        try {
            [xml]$machineConfig = Get-Content $ConfigPath
            Write-Host "machine.config loaded successfully."
        } catch {
            Write-Error ("Failed to load {0} for editing. Error: {1}" -f $ConfigPath, $_.Exception.Message)
            return
        }
    }

    $systemWebNode = $machineConfig.SelectSingleNode("/configuration/system.web")
    if ($systemWebNode -eq $null) {
        Write-Warning "Warning: '/configuration/system.web' node not found. Creating it now."
        $systemWebNode = $machineConfig.SelectSingleNode("/configuration").AppendChild($machineConfig.CreateElement("system.web"))
    }

    $processModelNode = $systemWebNode.SelectSingleNode("processModel")
    if ($processModelNode -ne $null) {
        Write-Host "Removing existing 'processModel' element from system.web."
        $systemWebNode.RemoveChild($processModelNode) | Out-Null
    } else {
        Write-Host "'processModel' element not found in system.web. Skipping removal."
    }

    $httpRuntimeNode = $systemWebNode.SelectSingleNode("httpRuntime")
    if ($httpRuntimeNode -ne $null) {
        Write-Host "Removing existing 'httpRuntime' element from system.web."
        $systemWebNode.RemoveChild($httpRuntimeNode) | Out-Null
    } else {
        Write-Host "'httpRuntime' element not found in system.web. Skipping removal."
    }

    $rootNode = $machineConfig.SelectSingleNode("/configuration")

    $systemNetNode = $rootNode.SelectSingleNode("system.net")
    if ($systemNetNode -ne $null) {
        Write-Host "Removing existing 'system.net' element from configuration root."
        $rootNode.RemoveChild($systemNetNode) | Out-Null
    } else {
        Write-Host "'system.net' element not found in configuration root. Skipping removal."
    }

    Write-Host "Creating and adding 'processModel' element to system.web."
    $processModelxml = $machineConfig.CreateElement("processModel")
    $processModelxml.setAttribute("autoConfig", "false")
    $processModelxml.setAttribute("maxWorkerThreads", 100)
    $processModelxml.setAttribute("maxIoThreads", 100)
    $processModelxml.setAttribute("minWorkerThreads", 50)
    $processModelxml.setAttribute("minIoThreads", 50)
    $systemWebNode.AppendChild($processModelxml) | Out-Null
    Write-Host "'processModel' element added."

    Write-Host "Creating and adding 'httpRuntime' element to system.web (Cores: $numberOfCores)."
    $httpRuntimexml = $machineConfig.CreateElement("httpRuntime")
    $httpRuntimexml.setAttribute("minFreeThreads", (88 * [int]$numberOfCores))
    $httpRuntimexml.setAttribute("minLocalRequestFreeThreads", (76 * [int]$numberOfCores))
    $systemWebNode.AppendChild($httpRuntimexml) | Out-Null
    Write-Host "'httpRuntime' element added."

    Write-Host "Creating and adding 'system.net' element to configuration root."
    $netxml = $machineConfig.CreateElement("system.net")
    $rootNode.AppendChild($netxml) | Out-Null
    Write-Host "'system.net' element added."

    Write-Host "Creating and adding 'connectionManagement' element to system.net."
    $connectionxml = $machineConfig.CreateElement("connectionManagement")
    $addxml = $machineConfig.CreateElement("add")
    $addxml.setAttribute("address", "*")
    $addxml.setAttribute("maxconnection", (12 * $numberOfCores))
    $connectionxml.AppendChild($addxml) | Out-Null
    $netxml.AppendChild($connectionxml) | Out-Null
    Write-Host "'connectionManagement' element added."

    try {
        Write-Host "Saving changes to '$ConfigPath'..."
        $machineConfig.OuterXml | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force
        Write-Host "Changes saved successfully for '$ConfigPath'." -ForegroundColor Green
    } catch {
        Write-Error ("Failed to save changes to {0}. Error: {1}" -f $ConfigPath, $_.Exception.Message)
    }
}

Write-Host "`n--- Starting machine.config updates ---" -ForegroundColor Yellow

Update-MachineConfig -ConfigPath $pathV2_32bit -BackupFolderPath $backupfolderV2_32bit
Update-MachineConfig -ConfigPath $pathV2_64bit -BackupFolderPath $backupfolderV2_64bit
Update-MachineConfig -ConfigPath $pathV4_32bit -BackupFolderPath $backupfolderV4_32bit
Update-MachineConfig -ConfigPath $pathV4_64bit -BackupFolderPath $backupfolderV4_64bit

Write-Host "`n--- All machine.config updates attempted. Please review messages above. ---" -ForegroundColor Green

# Define the script block to calculate and set page file settings
$scriptBlock = {
    param(
        [Parameter(Mandatory=$true)]
        [string]$installDriveLetter
    )
    $totalPhysicalMemoryGB = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    $initialSizeMB = [math]::Round(($totalPhysicalMemoryGB / 2) + $totalPhysicalMemoryGB) * 1024
    $maximumSizeMB = $initialSizeMB + 64
    $desiredValueData = "C:\pagefile.sys {0}MB {1}MB" -f $initialSizeMB, $maximumSizeMB

    Write-Host "Desired page file setting: C:\pagefile.sys InitialSize: ${initialSizeMB}MB, MaximumSize: ${maximumSizeMB}MB"

    try {
        $currentPagingFiles = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -ErrorAction SilentlyContinue).PagingFiles

        if ($currentPagingFiles -eq $desiredValueData) {
            Write-Host "Page file settings are already configured as desired. No change needed." -ForegroundColor Green
        } else {
            Write-Host "Page file settings are NOT configured as desired. Current: '$currentPagingFiles'. Setting now."
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Value $desiredValueData -Force
            Write-Host "Page file settings updated successfully." -ForegroundColor Green
        }
    } catch {
        Write-Error ("Failed to set page file settings: {0}" -f $_.Exception.Message)
    }
}

try {
    Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $installDrive -ErrorAction Stop
} catch {
    Write-Error ("Failed to set page file settings: {0}" -f $_.Exception.Message)
}

# --- IIS Log Cleaner Download and Extraction ---
Write-Log "`n--- Downloading and Extracting IIS Log Cleaner ---"
Write-Host "`n--- Downloading and Extracting IIS Log Cleaner ---" -ForegroundColor DarkCyan
$logCleanerZipUrl = "https://produpdates.blob.core.windows.net/web/Prerequisite%20application%202025/LogCleaner.zip?sp=rw&st=2025-11-17T14:20:36Z&se=2026-11-16T22:35:36Z&spr=https&sv=2024-11-04&sr=b&sig=0Oy7c9On7V55%2BUEtj6rsUXfYw%2F65rY57FNzctaaWHmk%3D"
Download-And-ExtractZip `
    -Url $logCleanerZipUrl `
    -ZipDestinationPath "${installDrive}:\PnxTemp\LogCleaner.zip" `
    -ExtractPath "${installDrive}:\PnxTemp\" `
    -FileName "LogCleaner.zip"

# Create a scheduled task in Task Scheduler to run the .bat file daily at 4:00 AM
Write-Log "`nCreating/Updating scheduled task 'Clean Logs in IIS'..."
Write-Host "`nCreating/Updating scheduled task 'Clean Logs in IIS'..."
$taskName = 'Clean Logs in IIS'
$taskPath = '\'
$taskDescription = 'IIS Log Cleaner'
$actionExecutable = 'C:\Windows\System32\cmd.exe'
$actionArguments = "/c ${installDrive}:\PnxTemp\LogCleaner\CleanLogs.bat"
$trigger = New-ScheduledTaskTrigger -Daily -At "4:00 AM"
$action = New-ScheduledTaskAction -Execute $actionExecutable -Argument $actionArguments

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel -WakeToRun
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

try {
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Log "Scheduled task '$taskName' already exists. Checking for updates."
        Write-Host "Scheduled task '$taskName' already exists. Checking for updates."
        Set-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal
        Write-Log "Scheduled task '$taskName' updated successfully."
        Write-Host "Scheduled task '$taskName' updated successfully." -ForegroundColor Green
    } else {
        Write-Log "Creating new scheduled task '$taskName'."
        Write-Host "Creating new scheduled task '$taskName'."
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $taskDescription
        Write-Log "Scheduled task '$taskName' created successfully."
        Write-Host "Scheduled task '$taskName' created successfully." -ForegroundColor Green
    }
} catch {
    Write-Log ("Failed to create/update scheduled task '{0}': {1}" -f $taskName, $_.Exception.Message) -Level ERROR
    Write-Error ("Failed to create/update scheduled task '{0}': {1}" -f $taskName, $_.Exception.Message)
}

# Configure firewall ports
Write-Log "`n--- Configuring Firewall Ports ---"
Write-Host "`n--- Configuring Firewall Ports ---" -ForegroundColor Yellow
$requiredPorts = @(80, 443, 8888, 8889, 8080, 6666, 6667, 8245, 7005, 6990, 9998, 8090, 3000, 5555, 9600, 1433, 8081, 8182, 8181)

foreach ($port in $requiredPorts) {
    $ruleName = "ProPhoenix Port $port"
    try {
        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $ruleName `
                                -Direction Inbound `
                                -Action Allow `
                                -Protocol TCP `
                                -LocalPort $port `
                                -Profile Any -ErrorAction Stop | Out-Null
            Write-Log "[Firewall] Rule created for port $port"
            Write-Output "[Firewall] Rule created for port $port"
        } else {
            Write-Log "[Firewall] Rule already exists for port $port"
            Write-Output "[Firewall] Rule already exists for port $port"
        }
    } catch {
        Write-Log ("[Firewall] Failed to configure rule for port {0}: {1}" -f $port, $_.Exception.Message) -Level ERROR
        Write-Error ("[Firewall] Failed to configure rule for port {0}: {1}" -f $port, $_.Exception.Message)
    }
}

# --- Forcing Windows Update Settings to 'Download Only' (No Restart Required) ---
Write-Log "`n--- Forcing Windows Update Settings to 'Download Only' (No Restart Required) ---"
Write-Host "`n--- Forcing Windows Update Settings to 'Download Only' (No Restart Required) ---" -ForegroundColor Yellow

try {
    $regPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $valueName = "AUOptions"
    $valueData = 3
    $noAutoUpdateValueName = "NoAutoUpdate"
    $changesMade = $false

    if (-not (Test-Path $regPolicyPath)) {
        New-Item -Path $regPolicyPath -Force | Out-Null
        Write-Log "Created registry key for Windows Update policies: $regPolicyPath"
        Write-Host "Created registry key for Windows Update policies: $regPolicyPath" -ForegroundColor Green
        $changesMade = $true
    }

    $currentAUOptions = $null
    try {
        $currentAUOptions = (Get-ItemProperty -Path $regPolicyPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
    } catch {}

    if ($currentAUOptions -ne $valueData) {
        Set-ItemProperty -Path $regPolicyPath -Name $valueName -Value $valueData -Force -ErrorAction Stop
        Write-Log "Windows Update setting 'AUOptions' set to $valueData (Auto download and notify for install)."
        Write-Log "This means updates will download automatically, but you control when they install."
        Write-Host "Windows Update setting 'AUOptions' set to $valueData (Auto download and notify for install)." -ForegroundColor Green
        Write-Host "This means updates will download automatically, but you control when they install." -ForegroundColor Cyan
        $changesMade = $true
    } else {
        Write-Log "Windows Update setting 'AUOptions' is already set to $valueData. No change needed."
        Write-Host "Windows Update setting 'AUOptions' is already set to $valueData. No change needed." -ForegroundColor Cyan
    }

    $currentNoAutoUpdate = $null
    try {
        $currentNoAutoUpdate = (Get-ItemProperty -Path $regPolicyPath -Name $noAutoUpdateValueName -ErrorAction SilentlyContinue).$noAutoUpdateValueName
    } catch {}

    if ($currentNoAutoUpdate -eq 1) {
        Remove-ItemProperty -Path $regPolicyPath -Name $noAutoUpdateValueName -Force -ErrorAction Stop
        Write-Log "'NoAutoUpdate' policy was set to disable updates. Removed it to allow 'Download Only'." -Level WARNING
        Write-Host "'NoAutoUpdate' policy was set to disable updates. Removed it to allow 'Download Only'." -ForegroundColor Yellow
        $changesMade = $true
    } elseif ($currentNoAutoUpdate -eq 0) {
        Write-Log "'NoAutoUpdate' policy is correctly set to 0 (allowing updates)."
        Write-Host "'NoAutoUpdate' policy is correctly set to 0 (allowing updates)." -ForegroundColor Cyan
    } else {
        Write-Log "'NoAutoUpdate' policy is not present or not set to 1. Good."
        Write-Host "'NoAutoUpdate' policy is not present or not set to 1. Good." -ForegroundColor DarkGray
    }

    if ($changesMade) {
        Write-Log "Forcing Group Policy update to apply registry changes..." -Level WARNING
        Write-Host "Forcing Group Policy update to apply registry changes..." -ForegroundColor DarkYellow
        & gpupdate /force

        Write-Log "Restarting 'Windows Update' service (wuauserv) for immediate configuration refresh..." -Level WARNING
        Write-Host "Restarting 'Windows Update' service (wuauserv) for immediate configuration refresh..." -ForegroundColor DarkYellow
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue | Out-Null
        Start-Service -Name "wuauserv" -ErrorAction Stop
        Write-Log "'Windows Update' service restarted successfully."
        Write-Host "'Windows Update' service restarted successfully." -ForegroundColor Green
        Write-Log "Windows Update settings should now be 'Download Only' without a system restart."
        Write-Host "Windows Update settings should now be 'Download Only' without a system restart." -ForegroundColor Green
    } else {
        Write-Log "No changes were needed for Windows Update settings."
        Write-Host "No changes were needed for Windows Update settings." -ForegroundColor Cyan
    }

} catch {
    Write-Log ("Failed to configure Windows Update settings: {0}" -f $_.Exception.Message) -Level ERROR
    Write-Error ("Failed to configure Windows Update settings: {0}" -f $_.Exception.Message)
}

Write-Log "`n✅ All setup tasks completed successfully."
Write-Output "`n✅ All setup tasks completed successfully."
