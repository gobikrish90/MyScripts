<#
.SYNOPSIS
  Finds all "SvrSessionData" folders under CAD server instance folders,
  deletes ALL files inside them, and highlights status + instance path.

.NOTES
  Run PowerShell as Administrator.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CadInstancesRoot = "C:\Program Files\ProPhoenix\CAD Server\_Instances",
    [string]$SessionFolderName = "SvrSessionData"
)

function Write-Status {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host ("[{0}] {1}" -f $timestamp, $Message) -ForegroundColor $Color
}

Write-Status "===== SvrSessionData FILE CLEANUP STARTED =====" Cyan
Write-Status ("ROOT PATH : {0}" -f $CadInstancesRoot) Yellow
Write-Status ("TARGET FOLDER : {0}" -f $SessionFolderName) Yellow

if (-not (Test-Path $CadInstancesRoot)) {
    Write-Status ("ERROR: Root path not found: {0}" -f $CadInstancesRoot) Red
    exit 1
}

# Find all SvrSessionData folders
$sessionFolders = Get-ChildItem -Path $CadInstancesRoot -Directory -Recurse -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -ieq $SessionFolderName }

$totalSessionFolders = 0
$totalFiles          = 0
$successCount        = 0
$failCount           = 0

foreach ($folder in $sessionFolders) {
    $totalSessionFolders++

    $instanceFolder = Split-Path $folder.FullName -Parent
    $instanceName   = Split-Path $instanceFolder -Leaf

    Write-Status "------------------------------------------------------------" DarkGray
    Write-Status ("INSTANCE NAME : {0}" -f $instanceName) Cyan
    Write-Status ("INSTANCE PATH : {0}" -f $instanceFolder) Cyan
    Write-Status ("SVRSESSIONDATA : {0}" -f $folder.FullName) Cyan
    Write-Status "------------------------------------------------------------" DarkGray

    # Get ALL files inside SvrSessionData
    $files = Get-ChildItem -Path $folder.FullName -File -Recurse -ErrorAction SilentlyContinue

    if (-not $files -or $files.Count -eq 0) {
        Write-Status ("NO FILES FOUND") Yellow
        continue
    }

    foreach ($file in $files) {
        $totalFiles++

        if (-not $PSCmdlet.ShouldProcess($file.FullName, "DELETE")) {
            Write-Status ("SKIPPED (WhatIf): {0}" -f $file.FullName) Yellow
            continue
        }

        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            Write-Status ("DELETED: {0}" -f $file.FullName) Green
            $successCount++
        }
        catch {
            Write-Status ("FAILED: {0} - {1}" -f $file.FullName, $_.Exception.Message) Red
            $failCount++
        }
    }
}

Write-Status "============================================================" Cyan
Write-Status "====================== CLEANUP SUMMARY =====================" Cyan
Write-Status ("SvrSessionData folders found : {0}" -f $totalSessionFolders) White
Write-Status ("Files found                  : {0}" -f $totalFiles) White
Write-Status ("Successfully deleted         : {0}" -f $successCount) Green
Write-Status ("Failed deletions             : {0}" -f $failCount) Red
Write-Status "=================== FILE CLEANUP COMPLETED =================" Cyan
Write-Status "============================================================" Cyan
