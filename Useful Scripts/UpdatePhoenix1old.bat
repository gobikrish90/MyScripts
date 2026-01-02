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
$basePath = "D:\Program Files\ProPhoenix"
$oldName  = "Phoenix WDA V2"
$newName  = "Phoenix WDA V2 2024R2"
$exeName  = "Phoenix.WDAV2.Client.Shell.exe"
$procName = "Phoenix.WDAV2.Client.Shell"

$oldFullPath = Join-Path $basePath $oldName
$newFullPath = Join-Path $basePath $newName

Write-Host "--- Phoenix Update Utility ---" -ForegroundColor Cyan

# --- Step 1: Stop Process ---
Write-Host "`n1. Checking for running process..." -ForegroundColor Cyan
$proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
if ($proc) {
    Stop-Process -Name $procName -Force
    Write-Host "   Process terminated." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
} else {
    Write-Host "   Process not running." -ForegroundColor Gray
}

# --- Step 2: Rename Folder ---
Write-Host "`n2. Renaming Folder..." -ForegroundColor Cyan
if (Test-Path $oldFullPath) {
    try {
        Rename-Item -Path $oldFullPath -NewName $newName -ErrorAction Stop
        Write-Host "   Success: Renamed to $newName" -ForegroundColor Green
    } catch {
        Write-Error "   Failed to rename: $($_.Exception.Message)"
    }
} elseif (Test-Path $newFullPath) {
    Write-Host "   Folder already renamed." -ForegroundColor Gray
} else {
    Write-Host "   Old folder not found." -ForegroundColor Red
}

# --- Step 3: Create Shortcut ---
Write-Host "`n3. Creating Desktop Shortcut..." -ForegroundColor Cyan
$newExePath = Join-Path $newFullPath $exeName
if (Test-Path $newExePath) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\WDA V2 2024R2.lnk")
    $sc.TargetPath = $newExePath
    $sc.WorkingDirectory = $newFullPath
    $sc.Description = "Phoenix WDA V2 2024R2"
    $sc.Save()
    Write-Host "   Success: Shortcut created." -ForegroundColor Green
} else {
    Write-Error "   Executable not found for shortcut."
}

# --- Step 4: Update Environment Path ---
Write-Host "`n4. Updating System Environment Path..." -ForegroundColor Cyan

# Get current Machine (System) Path
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Check if the OLD path exists in the variable
if ($currentPath -like "*$oldFullPath*") {
    # Replace old path string with new path string
    $updatedPath = $currentPath.Replace($oldFullPath, $newFullPath)
    
    try {
        [Environment]::SetEnvironmentVariable("Path", $updatedPath, "Machine")
        Write-Host "   Success: Environment Path updated." -ForegroundColor Green
        Write-Host "   Old: ...$oldName..." -ForegroundColor Gray
        Write-Host "   New: ...$newName..." -ForegroundColor Gray
    } catch {
        Write-Error "   Failed to update Path. $($_.Exception.Message)"
    }
} elseif ($currentPath -like "*$newFullPath*") {
    Write-Host "   Path already contains the new folder." -ForegroundColor Gray
} else {
    Write-Host "   The old folder path was not found in the System Path variables. No changes made." -ForegroundColor Yellow
}