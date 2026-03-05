$exe = 'D:\OneDrive\OneDrive - ProPhoenix Corporation\Documents\GitHub\MyScripts\Installation Master\Prophoenix_Installation_Dashboard.exe'
$st  = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe'
$thumb = 'D4759912B7F330A9F7246933A7D037DED8ACEB27'  # one from your list

& $st sign `
  /sha1 $thumb `
  /fd SHA256 `
  /tr http://timestamp.digicert.com `
  /td SHA256 `
  /d  "Prophoenix Installation Dashboard" `
  /du "https://www.prophoenix.com" `
  "$exe"