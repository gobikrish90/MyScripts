@echo off
echo ==============================================
echo ProPhoenix Server Application Manager Installer
echo Auto-detects Program Files (x86) path
echo ==============================================

@echo off
setlocal enabledelayedexpansion

set "AppFolder=\ProPhoenix\Server Application Manager"

for %%D in (C D E F G) do (
    if exist "%%D:\Program Files (x86)%AppFolder%" (
        set "AppMgrExePath=%%D:\Program Files (x86)%AppFolder%"
        goto :found
    )
)

echo Server Application Manager not found!
exit /b

:found
cd /d "%AppMgrExePath%"
echo Found and switched to: %AppMgrExePath%


:: --------------------------------------------------
:: Step 1 - Installing RMS Products
:: --------------------------------------------------
"%AppMgrExePath%\PnxAppMgr.exe" "INSTALL" "PoliceRMS" "FireRMS" "InternalAffair"

echo.
:: Show WARNING in yellow
color 0E
echo ==================================================
echo   WARNING: Once CAD installation starts,
echo   the script will take down all CAD services.
echo ==================================================
color 07
echo.

:Prompt
set /p userChoice="Is CAD product available on this server? (Y/N): "

if /I "%userChoice%"=="Y" goto InstallCAD
if /I "%userChoice%"=="N" goto EndScript

echo Invalid choice. Please enter Y or N.
goto Prompt

:InstallCAD
echo.
echo Running CAD installation and update process...
cd /d "%AppMgrExePath%"

:: --------------------------------------------------
:: Step 2 - Installing CAD Products
:: --------------------------------------------------

"%AppMgrExePath%\PnxAppMgr.exe" "INSTALL" "DBUtility" "CADServer" "E911Server" "GPSServer" "ExternalInterface" "NCICServer" "NCICStateServer" "KGISPDServer" "DeviceNotification" "PnxWDAAppWebService" "StreamingNotification" "PhoenixTExt2Dispatch" "CAD2CADTellusServer" "ReportWriterAPI" "ADRWebService" "DocsServer" "PDFService" "StageCADClient" "StageWDA" "StageClientAppManager" "StagePhoenixWDAV2" "JobServer" "TraCSServer" "ReportServer" "PhoenixWebService" "FireWebService" "ProvisionManager" "FolderWatcher" "NIBRS"

echo.
echo Stopping all Phoenix services...
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name $_.Name -Force }"
echo All Phoenix services have been stopped.

:: --------------------------------------------------
:: Step 2.5 - Run Cleanup PowerShell Script
:: --------------------------------------------------
echo.
REM Run the PowerShell log clearance script
echo Running Log Clearance script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Log Clearence 2.0.ps1"
if %errorlevel% neq 0 (
    echo Log Clearance script failed. Exiting...
    exit /b %errorlevel%
)
echo Log Clearance completed successfully.
echo.


:: --------------------------------------------------
:: Step 3 - Updating CAD Service Instances
:: --------------------------------------------------
"%AppMgrExePath%\PnxAppMgr.exe" "UPDATEINSTANCE" ^
 "CADServer" "EmailWatcher" "CADNLBServer" "CAD2CADTellusServer" "E911Server" "ZetronServer" "ExternalInterface" "GPSServer" "NCICServer" "NCICStateServer" "FTPServer" "LocutionCADVoiceServer" "DeviceNotification" "StreamingNotification" "ReportService" "FolderWatcher" "DocsServer" "PhoenixTonerServer" "PhoenixAlertApp" "PhoenixTExt2Dispatch" "JobServer" "TraCSServer" "FolderWatcher" "EmailWatcher"


echo.
echo Starting all Phoenix services...
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { $_.Status -eq 'Stopped' } | ForEach-Object { Start-Service -Name $_.Name }"
echo All Phoenix services have been restarted.

echo.
echo CAD Installation and updates completed successfully.


:EndScript
echo.
echo Script execution completed. Press any key to exit.
pause >nul
