Write-Host "========================================="
Write-Host "            SCRIPT STARTED               "
Write-Host "=========================================`n"

# --------------------------------------------------------------------
# FUNCTION: Clear-SvrSessionData
# (Adapted from your SvrSessionData Clear_1.ps1)
# --------------------------------------------------------------------
function Clear-SvrSessionData {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$SessionFolderName = "SvrSessionData",
        [switch]$FullScan
    )

    # ----------------- Logging -----------------
    $logRoot = Join-Path -Path $env:SystemDrive -ChildPath "ProPhoenix\MaintenanceLogs"

    if (-not (Test-Path $logRoot)) {
        New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    }

    $logFile = Join-Path $logRoot ("SvrSessionData-Cleanup-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))

    function Write-Status {
        param([string]$Message)

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "[{0}] {1}" -f $timestamp, $Message

        Write-Host $line
        Add-Content -Path $logFile -Value $line
    }

    Write-Status "===== SvrSessionData FILE CLEANUP STARTED ====="
    Write-Status ("Session folder name: {0}" -f $SessionFolderName)
    Write-Status ("Log file           : {0}" -f $logFile)

    # ----------------- 1) Preferred ProPhoenix paths (fast) -----------------
    $preferredRoots = @(
        "C:\ProPhoenix",
        "D:\ProPhoenix",
        "E:\ProPhoenix",
        "$env:ProgramFiles\ProPhoenix",
        "$env:ProgramFiles(x86)\ProPhoenix",
        "$env:ProgramData\ProPhoenix"
    )

    $existingPreferredRoots = $preferredRoots | Where-Object { Test-Path $_ }

    if ($existingPreferredRoots.Count -gt 0) {
        Write-Status "Searching preferred ProPhoenix paths:"
        $existingPreferredRoots | ForEach-Object { Write-Status ("  {0}" -f $_) }
    }
    else {
        Write-Status "No preferred ProPhoenix paths found."
    }

    $sessionFolders = @()

    foreach ($root in $existingPreferredRoots) {
        try {
            Write-Status ("Scanning (preferred): {0}" -f $root)
            $sessionFolders += Get-ChildItem -Path $root -Directory -Recurse -Filter $SessionFolderName -ErrorAction SilentlyContinue
        }
        catch {
            Write-Status ("WARN: Failed to scan {0} - {1}" -f $root, $_.Exception.Message)
        }
    }

    # ----------------- 2) Optional full scan of all fixed drives -----------------
    if ($sessionFolders.Count -eq 0 -and $FullScan) {
        Write-Status "No folders found in preferred paths. Starting FULL SCAN of all fixed drives (can be slow)..."

        $searchRoots = Get-PSDrive -PSProvider FileSystem |
                       Where-Object { $_.Root -match '^[A-Z]:\\$' } |
                       Select-Object -ExpandProperty Root

        if (-not $searchRoots -or $searchRoots.Count -eq 0) {
            Write-Status "ERROR: No filesystem drives found to search."
            return
        }

        Write-Status "Full scan roots:"
        $searchRoots | ForEach-Object { Write-Status ("  {0}" -f $_) }

        foreach ($root in $searchRoots) {
            try {
                Write-Status ("Scanning (full): {0}" -f $root)
                $sessionFolders += Get-ChildItem -Path $root -Directory -Recurse -Filter $SessionFolderName -ErrorAction SilentlyContinue
            }
            catch {
                Write-Status ("WARN: Failed to scan {0} - {1}" -f $root, $_.Exception.Message)
            }
        }
    }
    elseif ($sessionFolders.Count -eq 0 -and -not $FullScan) {
        Write-Status "No folders found in preferred paths."
        Write-Status "If you want to scan the entire environment, re-run the script with -FullScan (may take time)."
    }

    # ----------------- Deletion logic -----------------
    $totalSessionFolders = 0
    $totalFiles          = 0
    $successCount        = 0
    $failCount           = 0

    if (-not $sessionFolders -or $sessionFolders.Count -eq 0) {
        Write-Status ("No '{0}' folders found." -f $SessionFolderName)
    }
    else {
        $totalSessionFolders = $sessionFolders.Count
        Write-Status ("Found {0} '{1}' folders." -f $totalSessionFolders, $SessionFolderName)

        foreach ($folder in $sessionFolders) {
            Write-Status ("Processing folder: {0}" -f $folder.FullName)

            try {
                $files = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue
            }
            catch {
                Write-Status ("WARN: Failed to list files in {0} - {1}" -f $folder.FullName, $_.Exception.Message)
                continue
            }

            if (-not $files -or $files.Count -eq 0) {
                Write-Status "  No files found in this folder."
                continue
            }

            $totalFiles += $files.Count

            foreach ($file in $files) {
                if ($PSCmdlet.ShouldProcess($file.FullName, "Delete")) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        Write-Status ("DELETED: {0}" -f $file.FullName)
                        $successCount++
                    }
                    catch {
                        Write-Status ("FAILED: {0} - {1}" -f $file.FullName, $_.Exception.Message)
                        $failCount++
                    }
                }
            }
        }
    }

    # ----------------- Summary -----------------
    Write-Status "===== CLEANUP SUMMARY ====="
    Write-Status ("SvrSessionData folders found : {0}" -f $totalSessionFolders)
    Write-Status ("Files found                  : {0}" -f $totalFiles)
    Write-Status ("Successfully deleted         : {0}" -f $successCount)
    Write-Status ("Failed to delete             : {0}" -f $failCount)
    Write-Status "===== SvrSessionData FILE CLEANUP COMPLETED ====="
}

# --------------------------------------------------------------------
# PART 1: PnxLog processing (your earlier script)
# --------------------------------------------------------------------

# Get all available drives and search for ProPhoenix directories that contain "_Instances"
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    "$($_.Root)Program Files\ProPhoenix"
} | Where-Object { Test-Path -Path $_ }

Write-Host "[INFO] Searching for '_Instances' folders...`n"

# Get all instance folders dynamically (folders that contain a _Instances subfolder)
$instanceFolders = foreach ($basePath in $proPhoenixBasePaths) {
    Get-ChildItem -Path $basePath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {
        Test-Path -Path "$($_.FullName)\_Instances"
    }
}

if (-not $instanceFolders -or $instanceFolders.Count -eq 0) {
    Write-Host "[WARNING] No '_Instances' folders found under any ProPhoenix path. Skipping PnxLog processing..."
}
else {
    Write-Host "[INFO] Detecting environment types..."

    # Find all environment types dynamically by scanning the '_Instances' folder
    $environmentTypes = @()

    foreach ($folder in $instanceFolders) {
        $envFolderPath = Join-Path $folder.FullName "_Instances"

        if (Test-Path -Path $envFolderPath) {
            $envFolders = Get-ChildItem -Path $envFolderPath -Directory -ErrorAction SilentlyContinue |
                          Select-Object -ExpandProperty Name
            $environmentTypes += $envFolders
        }
    }

    $environmentTypes = $environmentTypes | Sort-Object -Unique

    if (-not $environmentTypes -or $environmentTypes.Count -eq 0) {
        Write-Host "[WARNING] No environment folders found inside any '_Instances' folder. Skipping PnxLog processing..."
    }
    else {
        Write-Host "[SUCCESS] Found environments: $($environmentTypes -join ', ')`n"

        Write-Host "========================================="
        Write-Host "          PROCESSING LOG FILES           "
        Write-Host "========================================="

        foreach ($folder in $instanceFolders) {
            foreach ($environmentType in $environmentTypes) {

                $instancesPath = Join-Path $folder.FullName "_Instances"
                $targetPath    = Join-Path (Join-Path $instancesPath $environmentType) "PnxLog"
                $oldFolderPath = Join-Path $targetPath "old"

                if (Test-Path -Path $targetPath) {
                    # Get all files directly under PnxLog (not inside 'old')
                    $filesToMove = Get-ChildItem -Path $targetPath -File -ErrorAction SilentlyContinue |
                                   Where-Object { $_.FullName -notlike "$oldFolderPath*" }

                    if ($filesToMove -and $filesToMove.Count -gt 0) {
                        # Ensure 'old' folder exists
                        if (-not (Test-Path -Path $oldFolderPath)) {
                            New-Item -ItemType Directory -Path $oldFolderPath | Out-Null
                        }

                        # Clear existing files in 'old'
                        Get-ChildItem -Path $oldFolderPath -File -ErrorAction SilentlyContinue | Remove-Item -Force

                        # Move current log files into 'old'
                        foreach ($file in $filesToMove) {
                            Move-Item -Path $file.FullName -Destination $oldFolderPath -Force
                        }

                        Write-Host "[SUCCESS] Logs processed for environment '$environmentType' at: $targetPath"
                    }
                    else {
                        Write-Host "[INFO] No log files found in: $targetPath. Skipping..."
                    }
                }
                else {
                    Write-Host "[INFO] PnxLog folder not found for environment '$environmentType' at: $instancesPath"
                }
            }
        }
    }
}

# --------------------------------------------------------------------
# PART 2: Run SvrSessionData cleanup
# --------------------------------------------------------------------
Write-Host "`n========================================="
Write-Host "      CLEARING SVRSESSIONDATA FOLDERS    "
Write-Host "=========================================`n"

# Call with defaults (preferred ProPhoenix paths only)
# If you want full-environment scan, edit this call to: Clear-SvrSessionData -FullScan
Clear-SvrSessionData

Write-Host "`n========================================="
Write-Host "            SCRIPT COMPLETED             "
Write-Host "========================================="
