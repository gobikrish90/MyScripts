<#
.SYNOPSIS
  Finds all "SvrSessionData" folders, deletes ALL files inside them,
  and logs status to console and log file.

.NOTES
  Run PowerShell as Administrator.

  Example (safe / dry run, only common ProPhoenix paths):
    .\Clear-SvrSessionData.ps1 -WhatIf

  Example (actually delete, only common ProPhoenix paths):
    .\Clear-SvrSessionData.ps1

  Example (full environment scan – can be slow):
    .\Clear-SvrSessionData.ps1 -FullScan
#>

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
        exit 1
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
    $sessionFolders = $sessionFolders | Sort-Object -Property FullName -Unique

    foreach ($folder in $sessionFolders) {
        $totalSessionFolders++

        $parentFolder = Split-Path $folder.FullName -Parent
        $parentName   = Split-Path $parentFolder -Leaf

        Write-Status ("Found SvrSessionData folder: {0} (Parent: {1})" -f $folder.FullName, $parentName)

        $files = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue

        if (-not $files -or $files.Count -eq 0) {
            Write-Status ("No files found under: {0}" -f $folder.FullName)
            continue
        }

        foreach ($file in $files) {
            $totalFiles++

            if (-not $PSCmdlet.ShouldProcess($file.FullName, "DELETE")) {
                Write-Status ("SKIPPED (WhatIf): {0}" -f $file.FullName)
                continue
            }

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

# ----------------- Summary -----------------
Write-Status "===== CLEANUP SUMMARY ====="
Write-Status ("SvrSessionData folders found : {0}" -f $totalSessionFolders)
Write-Status ("Files found                  : {0}" -f $totalFiles)
Write-Status ("Successfully deleted         : {0}" -f $successCount)
Write-Status ("Failed to delete             : {0}" -f $failCount)
Write-Status "===== SvrSessionData FILE CLEANUP COMPLETED ====="
