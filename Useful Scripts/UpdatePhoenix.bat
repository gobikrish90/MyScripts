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

:: --- Run the PowerShell Logic below ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join \"`n\")"
echo.
echo ========================================================
echo   Script Finished. Press any key to close this window.
echo ========================================================
pause >nul
exit /b
#>

# --- POWERSHELL SCRIPT STARTS HERE ---

# Configuration
$baseSearchPath = $env:ProgramFiles 
$targetSubPath = "ProPhoenix"
$oldFolderName = "Phoenix WDA V2"
$newFolderName = "Phoenix WDA V2 2024R2"
$exeName = "Phoenix.WDAV2.Client.Shell.exe"
$processName = "Phoenix.WDAV2.Client.Shell"
$shortcutName = "WDA V2 2024R2"

Write-Host "--- Phoenix Update Script ---" -ForegroundColor Cyan
Write-Host "Target Base: $baseSearchPath\$targetSubPath" -ForegroundColor Gray

# Construct full paths
$proPhoenixBase = Join-Path -Path $baseSearchPath -ChildPath $targetSubPath
$oldFolderPath = Join-Path -Path $proPhoenixBase -ChildPath $oldFolderName
$newFolderPath = Join-Path -Path $proPhoenixBase -ChildPath $newFolderName

# --- Step 1: Kill the Process if Running ---
Write-Host "`n1. Checking for running process '$processName'..." -ForegroundColor Cyan
$runningProcess = Get-Process -Name $processName -ErrorAction SilentlyContinue

if ($runningProcess) {
    try {
        Stop-Process -Name $processName -Force -ErrorAction Stop
        Write-Host "   Process found. Terminating..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2 # Wait for Windows to release file locks
        Write-Host "   Success: Process terminated." -ForegroundColor Green
    }
    catch {
        Write-Error "   Failed to stop the process. Access Denied or process stuck."
        exit
    }
} else {
    Write-Host "   Process is not running." -ForegroundColor Gray
}

# --- Step 2: Find and Rename the Folder ---
Write-Host "`n2. Renaming Folder..." -ForegroundColor Cyan

if (Test-Path -Path $oldFolderPath) {
    try {
        Rename-Item -Path $oldFolderPath -NewName $newFolderName -ErrorAction Stop
        Write-Host "   Success: Folder renamed to '$newFolderName'" -ForegroundColor Green
    }
    catch {
        Write-Error "   Failed to rename folder." 
        Write-Error "   Error Details: $($_.Exception.Message)"
        exit
    }
}
elseif (Test-Path -Path $newFolderPath) {
    Write-Host "   Folder is already named '$newFolderName'. Skipping rename." -ForegroundColor Yellow
}
else {
    Write-Error "   CRITICAL: Could not find folder '$oldFolderName' or '$newFolderName' in '$proPhoenixBase'."
    Write-Host "   Please check if the path exists manually." -ForegroundColor Red
    exit
}

# --- Step 3: Create Desktop Shortcut ---
Write-Host "`n3. Creating Desktop Shortcut..." -ForegroundColor Cyan
$newExePath = Join-Path -Path $newFolderPath -ChildPath $exeName

if (Test-Path -Path $newExePath) {
    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path -Path $desktopPath -ChildPath "$shortcutName.lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $newExePath
        $Shortcut.WorkingDirectory = $newFolderPath
        $Shortcut.Description = "Shortcut to Phoenix WDA V2 2024R2"
        $Shortcut.Save()
        
        Write-Host "   Success: Shortcut '$shortcutName' created on Desktop." -ForegroundColor Green
    }
    catch {
        Write-Error "   Failed to create shortcut."
        Write-Error "   $($_.Exception.Message)"
    }
}
else {
    Write-Error "   The executable '$exeName' was not found inside the new folder."
}