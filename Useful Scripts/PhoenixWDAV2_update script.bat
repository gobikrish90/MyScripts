<# : batch script portion
@echo off
setlocal
cd /d %~dp0

:: --- Admin Privileges Check ---
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: --- Run the PowerShell Logic ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join \"`n\")"
echo.
echo ========================================================
echo   Script Finished. Press any key to close.
echo ========================================================
pause >nul
exit /b
#>

# --- POWERSHELL STARTS HERE ---

# --- Configuration ---
$searchPathStructure = "Program Files\ProPhoenix\Phoenix WDA V2"
$newName             = "Phoenix WDA V2 2024R2"
$exeName             = "Phoenix.WDAV2.Client.Shell.exe"
$procName            = "Phoenix.WDAV2.Client.Shell"
$shortcutName        = "WDA V2 2024R2"

Write-Host "--- Phoenix Update Utility (Multi-Drive Search) ---" -ForegroundColor Cyan

# --- Step 1: Find the Installation Path ---
Write-Host "`n1. Searching all drives for installation..." -ForegroundColor Cyan

$foundPath = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root.Length -eq 3 } # Gets C:\, D:\, etc.

foreach ($drive in $drives) {
    $potentialPath = Join-Path -Path $drive.Root -ChildPath $searchPathStructure
    Write-Host "   Checking $($drive.Root)..." -NoNewline -ForegroundColor DarkGray
    
    if (Test-Path $potentialPath) {
        Write-Host " FOUND!" -ForegroundColor Green
        $foundPath = $potentialPath
        break # Stop searching once found
    } else {
        Write-Host " -" -ForegroundColor DarkGray
    }
}

# If folder not found (maybe it was already renamed?), check for the NEW name just in case
if (-not $foundPath) {
    $renamedStructure = "Program Files\ProPhoenix\Phoenix WDA V2 2024R2"
    foreach ($drive in $drives) {
        $potentialNewPath = Join-Path -Path $drive.Root -ChildPath $renamedStructure
        if (Test-Path $potentialNewPath) {
            Write-Host "`n   Folder already appears to be renamed at: $potentialNewPath" -ForegroundColor Yellow
            $foundPath = $potentialNewPath
            # We skip rename logic but proceed to shortcut creation check
        }
    }
}

if (-not $foundPath) {
    Write-Host "`n   CRITICAL ERROR: Could not find '$searchPathStructure' on any drive." -ForegroundColor Red
    exit
}

# --- Step 2: Stop Process ---
Write-Host "`n2. Checking for running process..." -ForegroundColor Cyan
$proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
if ($proc) {
    try {
        Stop-Process -Name $procName -Force -ErrorAction Stop
        Write-Host "   Process '$procName' terminated." -ForegroundColor Yellow
        Start-Sleep -Seconds 2 # Wait for locks to release
    } catch {
        Write-Error "   Failed to stop process. It might need to be closed manually."
        exit
    }
} else {
    Write-Host "   Process is not running." -ForegroundColor Gray
}

# --- Step 3: Rename Folder ---
# Only rename if the folder ends with the OLD name
if ($foundPath.EndsWith("Phoenix WDA V2")) {
    Write-Host "`n3. Renaming Folder..." -ForegroundColor Cyan
    try {
        Rename-Item -Path $foundPath -NewName $newName -ErrorAction Stop
        # Update our variable to the new path so we can find the exe later
        $parentDir = Split-Path $foundPath -Parent
        $foundPath = Join-Path $parentDir $newName
        Write-Host "   Success: Renamed to '$newName'" -ForegroundColor Green
    } catch {
        Write-Error "   Failed to rename folder: $($_.Exception.Message)"
        exit
    }
} else {
    Write-Host "`n3. Folder rename skipped (already correct name)." -ForegroundColor Gray
}

# --- Step 4: Create Desktop Shortcut ---
Write-Host "`n4. Creating Desktop Shortcut..." -ForegroundColor Cyan
$newExePath = Join-Path -Path $foundPath -ChildPath $exeName

if (Test-Path $newExePath) {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutLocation = Join-Path $desktopPath "$shortcutName.lnk"
        
        $sc = $wsh.CreateShortcut($shortcutLocation)
        $sc.TargetPath = $newExePath
        $sc.WorkingDirectory = $foundPath
        $sc.Description = "Shortcut to Phoenix WDA V2 2024R2"
        $sc.Save()
        
        Write-Host "   Success: Shortcut '$shortcutName' created on Desktop." -ForegroundColor Green
    } catch {
        Write-Error "   Failed to create shortcut: $($_.Exception.Message)"
    }
} else {
    Write-Error "   The executable '$exeName' was not found inside '$foundPath'."
}