<#
.SYNOPSIS
    Creates and trusts a self-signed HTTPS certificate for local development.

.DESCRIPTION
    This script:
    - Adds 127.0.0.1 mapping for chpnx947.prophoenix.com
    - Creates a self-signed certificate
    - Installs it in the Trusted Root Certification Authorities store
    - Exports certificate and key files (optional)
#>

# -------------------------------
# CONFIGURATION
# -------------------------------
$domain = "chpnx862.prophoenix.com"
$certPassword = "P@ssw0rd!"      # Change this to something secure
$certPath = "C:\certs"           # Where certs will be saved

# -------------------------------
# STEP 1: Ensure cert directory exists
# -------------------------------
if (!(Test-Path $certPath)) {
    New-Item -ItemType Directory -Path $certPath | Out-Null
    Write-Host "Created directory: $certPath"
}

# -------------------------------
# STEP 2: Add hosts file entry
# -------------------------------
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$hostsEntry = "127.0.0.1`t$domain"

if ((Get-Content $hostsPath) -notmatch $domain) {
    Add-Content -Path $hostsPath -Value "`n$hostsEntry"
    Write-Host "Added hosts entry: $hostsEntry"
} else {
    Write-Host "Hosts entry already exists for $domain"
}

# -------------------------------
# STEP 3: Create self-signed certificate
# -------------------------------
Write-Host "Creating self-signed certificate for $domain ..."

$cert = New-SelfSignedCertificate `
    -DnsName $domain `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -FriendlyName "Local Dev Cert - $domain" `
    -NotAfter (Get-Date).AddYears(2)

Write-Host "Certificate created: $($cert.Subject)"

# -------------------------------
# STEP 4: Trust the certificate (add to Root store)
# -------------------------------
Write-Host "Trusting certificate..."
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()
Write-Host "Certificate trusted successfully."

# -------------------------------
# STEP 5: Export certificate to files (optional)
# -------------------------------
$pfxPath = Join-Path $certPath "$domain.pfx"
$crtPath = Join-Path $certPath "$domain.crt"

# Export PFX (includes private key)
Export-PfxCertificate `
    -Cert $cert `
    -FilePath $pfxPath `
    -Password (ConvertTo-SecureString -String $certPassword -Force -AsPlainText) `
    | Out-Null

# Export public certificate (CRT)
Export-Certificate `
    -Cert $cert `
    -FilePath $crtPath `
    | Out-Null

Write-Host "Exported certificate files:"
Write-Host "  PFX: $pfxPath"
Write-Host "  CRT: $crtPath"

Write-Host "`n✅ HTTPS setup complete for https://$domain"
Write-Host "You can now bind this certificate in IIS, Nginx, or your local app server."
