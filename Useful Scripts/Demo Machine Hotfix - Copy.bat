cd ../../
D:
cd "Program Files (x86)"
cd ProPhoenix
cd "Server Application Manager"

@echo off
SET AppMgrExePath="D:\Program Files (x86)\ProPhoenix\Server Application Manager"
SET PnxInstallPath=D:\Program Files\ProPhoenix

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "InstallUtilPath" "Path=C:\WINDOWS\Microsoft.NET\Framework\v4.0.30319"

::Script - Updating Application Manager
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER" 

@echo off
timeout 10 > NUL

:loopSelf
tasklist /fi "imagename eq PnxAppMgr.exe" |find ":" > nul
if "%ERRORLEVEL%"=="1" goto loopSelf

::Script - Installing products
%AppMgrExePath%\PnxAppMgr.exe "INSTALL" "DocsServer" "DBUtility" "PoliceRMS" "FireRMS" "JobServer" "TraCSServer" "ReportServer" "PhoenixWebService" "FireWebService" "ProvisionManager" "FolderWatcher" "InternalAffair" "NIBRS" "EmailWatcher" "CADServer" "E911Server" "GPSServer" "ExternalInterface" "NCICServer" "NCICStateServer" "KGISPDServer" "DeviceNotification" "PnxWDAAppWebService" "StreamingNotification" "PhoenixTExt2Dispatch" "CAD2CADTellusServer" "ReportWriterAPI" "ADRWebService" "PDFService" "StageCADClient" "StageWDA" "StageClientAppManager" "StagePhoenixWDAV2" "PoliceF1HelpDocs" "FireF1HelpDocs" "IAF1HelpDocs" "HazMatGuide"

::Script - Creating Virtual Directory Instance - Start

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=PoliceRMS" "VirtualDirName=Law" "ParentWebsite=" "PnxCustHlpPath=" "PnxBulkUpldPath=" "PnxVideosPath="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=FireRMS" "VirtualDirName=Fire" "ParentWebsite=" "PnxCustHlpPath=" "PnxBulkUpldPath=" "PnxVideosPath="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=InternalAffair" "VirtualDirName=IA" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=ReportServer" "VirtualDirName=PnxRptSvr" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=PhoenixWebService" "VirtualDirName=WebService" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=KGISPDServer" "VirtualDirName=KGIS" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=HazMatGuide" "VirtualDirName=UserDocs" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=FireWebService" "VirtualDirName=FireWS" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=PnxWDAAppWebService" "VirtualDirName=WDAApp" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=ReportWriterAPI" "VirtualDirName=WDAV2API" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=ProvisionManager" "VirtualDirName=ProvisionManager" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=ADRWebService" "VirtualDirName=ADRRepository" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=NIBRS" "VirtualDirName=NIBRSService" "ParentWebsite="

%AppMgrExePath%\PnxAppMgr.exe "CREATEVIRTUALDIRINSTANCE" "Product=PDFService" "VirtualDirName=PhoenixPDFService" "ParentWebsite="

::Script - Creating Virtual Directory Instance - End

::Script - Creating Windows Service Instance - Start

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=JobServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=TraCSServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=EmailWatcher" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=CADServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=CAD2CADTellusServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=E911Server" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=ExternalInterface" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=GPSServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=NCICServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=NCICStateServer" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=DeviceNotification" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=FolderWatcher" "InstanceName=Live"

%AppMgrExePath%\PnxAppMgr.exe "CREATEWINSERVICEINSTANCE" "Product=DocsServer" "InstanceName=Live"


::Script - Creating Windows Service Instance - End


echo Stopping all services...
 
:: Run PowerShell command to stop services
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name $_.Name -Force }"
 
echo All Phoenix services have been stopped.

::Show Instances
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES"

::Script - Updating Windows Service Instance
%AppMgrExePath%\PnxAppMgr.exe "UPDATEINSTANCE" "JobServer" "TraCSServer" "VideoServer" "FingerPrintServer" "EmailWatcher" "CADServer" "CADNLBServer" "CAD2CADTellusServer" "E911Server" "ZetronServer" "ExternalInterface" "GPSServer" "NCICServer" "NCICStateServer" "FTPServer" "LocutionCADVoiceServer" "DeviceNotification" "StreamingNotification" "ReportService" "FolderWatcher" "DocsServer" "PhoenixTonerServer" "PhoenixAlertApp" "PhoenixTExt2Dispatch"

echo Start all services...
 
:: Run PowerShell command to stop services
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { $_.Status -eq 'Stopped' } | ForEach-Object { Start-Service -Name $_.Name -Force }"

::Show Instances
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES"


Pause
::End of Script::