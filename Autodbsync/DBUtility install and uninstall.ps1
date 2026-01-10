<#
.SYNOPSIS
    DB Utility Single-File Reinstaller.
    - Generates ONE .bat file: "Reinstall_DBUtility.bat"
    - The BAT file performs Uninstall -> PAUSE -> Install.
#>

# ==============================================================================
#  1. SETUP
# ==============================================================================
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   DB Utility Reinstaller (Single File)" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$TargetServer = Read-Host "Enter Target Server Name (Press ENTER for Localhost)"

if ([string]::IsNullOrWhiteSpace($TargetServer)) {
    $TargetServer = "localhost"
    $RunRemote = $false
    Write-Host "-> Mode: LOCAL" -ForegroundColor Green
} else {
    $RunRemote = $true
    Write-Host "-> Mode: REMOTE ($TargetServer)" -ForegroundColor Yellow
}

# ==============================================================================
#  2. GENERATOR LOGIC
# ==============================================================================
$GeneratorLogic = {
    $ErrorActionPreference = "Continue"
    $CurrentHostName = $env:COMPUTERNAME
    
    # --- FIND APPREG_MAIN.XML ---
    $FileName = "Appreg_main.xml"
    Write-Host "`n[INFO] Scanning for $FileName..." -ForegroundColor Cyan

    $PossibleParents = @(
        "ProPhoenix\Server Application Manager",
        "Program Files (x86)\ProPhoenix\Server Application Manager",
        "Program Files\ProPhoenix\Server Application Manager"
    )
    
    $Drives = Get-PSDrive -PSProvider FileSystem
    $AppRegPath = $null

    foreach ($d in $Drives) {
        foreach ($folder in $PossibleParents) {
            $TryPath = Join-Path -Path $d.Root -ChildPath $folder | Join-Path -ChildPath $FileName
            if (Test-Path $TryPath) { $AppRegPath = $TryPath; break }
        }
        if ($AppRegPath) { break }
    }

    if (-not $AppRegPath) { Write-Error "Appreg_main.xml not found."; return }
    Write-Host "   Found: $AppRegPath" -ForegroundColor Gray

    # --- VALIDATE DB UTILITY ---
    try { [xml]$xmlData = Get-Content $AppRegPath } catch { Write-Error "Invalid XML"; return }
    $FoundDBUtil = $false

    if ($xmlData.PhoenixApplications.AppReg) {
        foreach ($app in $xmlData.PhoenixApplications.AppReg) {
            if ($app.AppPath -like "*Database Utility*" -and $app.AppPath -notlike "*CodeBook*") {
                $FoundDBUtil = $true; break
            }
        }
    }

    if (-not $FoundDBUtil) { Write-Warning "DB Utility not found in Appreg."; return }

    # --- GENERATE SINGLE BATCH FILE ---
    $AppMgrFolder = Split-Path -Path $AppRegPath -Parent
    $AppMgrDrive = Split-Path -Path $AppRegPath -Qualifier
    $PnxTemp = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
    if (-not (Test-Path $PnxTemp)) { New-Item -ItemType Directory -Path $PnxTemp -Force | Out-Null }

    # Path navigation logic
    $PathParts = $AppMgrFolder.Split('\')
    $CdBlock = "$AppMgrDrive`r`ncd ..\..\`r`n"
    for ($i = 1; $i -lt $PathParts.Count; $i++) { if ($PathParts[$i]) { $CdBlock += "cd `"$($PathParts[$i])`"`r`n" } }

    $BatchContent = @"
$CdBlock
@echo off
SET AppMgrExePath="$AppMgrFolder"

echo ===================================================
echo   DB UTILITY REINSTALLER (Step-by-Step)
echo ===================================================

echo.
echo [STEP 1] UNINSTALLING Database Utility...
"%AppMgrFolder\PnxAppMgr.exe" "UNINSTALL" "DBUtility"

echo.
echo ===================================================
echo   UNINSTALL COMPLETE.
echo   Check the output above for errors.
echo.
echo   [ACTION REQUIRED]
echo   Press ANY KEY to proceed with INSTALLATION.
echo   (Or close this window to stop here).
echo ===================================================
pause

echo.
echo [STEP 2] INSTALLING Database Utility...
"%AppMgrFolder\PnxAppMgr.exe" "INSTALL" "DBUtility"

echo.
echo ===================================================
echo   PROCESS COMPLETE.
echo ===================================================
pause
"@
    
    $BatFile = Join-Path $PnxTemp "Reinstall_DBUtility.bat"
    Set-Content -Path $BatFile -Value $BatchContent -Encoding ASCII

    Write-Host "`n[SUCCESS] Generated Single Batch File:" -ForegroundColor Green
    Write-Host "   Path: $BatFile"

    return $BatFile
}

# ==============================================================================
#  3. EXECUTION FLOW
# ==============================================================================
if ($RunRemote) {
    # Remote: Generate only
    $Creds = Get-Credential
    Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
    Write-Host "`n[NOTE] File generated on remote server. Login to run it." -ForegroundColor Yellow
} else {
    # Local: Generate AND Prompt
    $LocalFile = & $GeneratorLogic
    
    if ($LocalFile) {
        Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan
        $Ans = Read-Host "[QUESTION] Do you want to RUN the Reinstaller Batch file now? (y/n)"
        if ($Ans -eq "y") {
            Write-Host "Launching Batch File..." -ForegroundColor Green
            # Launches the BAT file. The BAT file handles the pause between uninstall/install.
            Start-Process -FilePath $LocalFile -Verb RunAs
        } else {
            Write-Host "Skipping execution. File is saved at: $LocalFile" -ForegroundColor Yellow
        }
    }
}