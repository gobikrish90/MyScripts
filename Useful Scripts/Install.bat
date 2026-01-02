cd ../../
cd "Program Files (x86)"
cd ProPhoenix
cd "Server Application Manager"

@echo off
SET AppMgrExePath="D:\Program Files (x86)\ProPhoenix\Server Application Manager"

:loopSelf
tasklist /fi "imagename eq PnxAppMgr.exe" |find ":" > nul
if "%ERRORLEVEL%"=="1" goto loopSelf

::Script - Installing products
%AppMgrExePath%\PnxAppMgr.exe "INSTALL" "DocsServer" "DBUtility" "PoliceRMS" "FireRMS" "JobServer" "TraCSServer" "ReportServer" "PhoenixWebService" "FireWebService" "ProvisionManager" "FolderWatcher" "InternalAffair" "NIBRS" "EmailWatcher" "CADServer" "E911Server" "GPSServer" "ExternalInterface" "NCICServer" "NCICStateServer" "KGISPDServer" "DeviceNotification" "PnxWDAAppWebService" "StreamingNotification" "PhoenixTExt2Dispatch" "CAD2CADTellusServer" "ReportWriterAPI" "ADRWebService" "PDFService" "StageCADClient" "StageWDA" "StageClientAppManager" "StagePhoenixWDAV2" "PoliceF1HelpDocs" "FireF1HelpDocs" "IAF1HelpDocs" "HazMatGuide"


Pause
::End of Script::