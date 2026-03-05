<#
Build-TrustableExe.ps1
Creates a windowed, STA, RequireAdmin EXE from a PowerShell WinForms script, then signs it.
Requires the PS2EXE module (Markus Scholtes). Parameters aligned with its documented switches.
#>

param(
  # Input PS1 and output EXE
  [string]$Input  = "D:\OneDrive\OneDrive - ProPhoenix Corporation\Documents\GitHub\MyScripts\Installation Master\InstallationMasterToolv4.9.ps1",
  [string]$Output = "D:\OneDrive\OneDrive - ProPhoenix Corporation\Documents\GitHub\MyScripts\Installation Master\Prophoenix_Installation_Dashboard.exe",

  # Optional icon for branding (.ico)
  [string]$Icon   = "D:\OneDrive\OneDrive - ProPhoenix Corporation\Documents\GitHub\MyScripts\Installation Master\ProPhoenix_Logo.ico",

  # Code signing (recommended)
  [string]$Pfx           = "",                   # e.g., .\Prophoenix-CodeSign.pfx (leave blank for EV token / sign later)
  [string]$PfxPassword   = "P@ssw0rd!",                   # provide if your PFX is password-protected
  [string]$TimestampUrl  = "http://timestamp.digicert.com",

  # Metadata
  [string]$ProductName   = "Prophoenix Installation Dashboard",
  [string]$CompanyName   = "Prophoenix",
  [string]$Description   = "Prophoenix Installation Dashboard (WinForms)",
  [string]$LegalUrl      = "https://www.prophoenix.com",
  [string]$Version       = "4.7.0.0"
)

$ErrorActionPreference = "Stop"

# Ensure output folder
$null = New-Item -ItemType Directory -Path (Split-Path $Output) -Force

# Make sure PS2EXE is installed (official module)
if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
  Write-Host "Installing ps2exe from PowerShell Gallery..." -ForegroundColor Cyan
  Install-Module ps2exe -Scope CurrentUser -Force
}

# Build EXE (parameters per official docs: title, description, company, product, copyright, version, etc.)
Write-Host "Building EXE..." -ForegroundColor Cyan
$ps2exeParams = @{
  InputFile      = $Input
  OutputFile     = $Output
  NoConsole      = $true          # WinForms app, hide console
  STA            = $true          # WinForms requires STA
  RequireAdmin   = $true          # UAC elevation manifest
  Title          = $ProductName
  Product        = $ProductName
  Company        = $CompanyName
  Description    = $Description
  Version        = $Version       # <-- single metadata version field (File/Product)
  Copyright      = "© $(Get-Date -Format yyyy) $CompanyName"
  DPIAware       = $true
  x64            = $true
}
if (Test-Path $Icon) { $ps2exeParams.IconFile = $Icon }

Invoke-ps2exe @ps2exeParams   # <- Note: case-insensitive, but keep this spelling

# Sign EXE (recommended). Requires Windows SDK's signtool.exe on PATH.
$signtool = Get-Command signtool.exe -ErrorAction SilentlyContinue
if (-not $signtool) {
  Write-Warning "signtool.exe not found. Install Windows 10/11 SDK or sign later on your signing machine."
} else {
  Write-Host "Signing EXE..." -ForegroundColor Cyan
  if ([string]::IsNullOrWhiteSpace($Pfx)) {
    # EV token or cert in store: auto-select best signing cert
    & "signtool.exe" sign /fd SHA256 /tr $TimestampUrl /td SHA256 /d $ProductName /du $LegalUrl /a $Output
  } else {
    if ([string]::IsNullOrWhiteSpace($PfxPassword)) {
      & "signtool.exe" sign /fd SHA256 /tr $TimestampUrl /td SHA256 /d $ProductName /du $LegalUrl /f $Pfx $Output
    } else {
      & "signtool.exe" sign /fd SHA256 /tr $TimestampUrl /td SHA256 /d $ProductName /du $LegalUrl /f $Pfx /p $PfxPassword $Output
    }
  }

  Write-Host "Verifying signature..." -ForegroundColor Cyan
  & "signtool.exe" verify /pa /v $Output | Out-Host
}

Write-Host "`nDone. EXE: $Output" -ForegroundColor Green