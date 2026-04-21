# ===========================================
# IIS Installation Script 
# ===========================================

# Core IIS and Common HTTP Features
Install-WindowsFeature -Name Web-Server
Install-WindowsFeature -Name Web-WebServer
Install-WindowsFeature -Name Web-Common-Http
Install-WindowsFeature -Name Web-Static-Content
Install-WindowsFeature -Name Web-Default-Doc
Install-WindowsFeature -Name Web-Dir-Browsing
Install-WindowsFeature -Name Web-Http-Errors
Install-WindowsFeature -Name Web-Http-Redirect

# FTP Server Features
Install-WindowsFeature -Name Web-Ftp-Server
Install-WindowsFeature -Name Web-Ftp-Service

# Application Development Features 
Install-WindowsFeature -Name Web-Asp-Net45
Install-WindowsFeature -Name Web-Net-Ext45
Install-WindowsFeature -Name Web-ISAPI-Ext
Install-WindowsFeature -Name Web-ISAPI-Filter
Install-WindowsFeature -Name Web-Net-Ext         # .NET Extensibility 3.5
Install-WindowsFeature -Name Web-AppInit         # Application Initialization
Install-WindowsFeature -Name Web-Asp             # ASP
Install-WindowsFeature -Name Web-Asp-Net         # ASP.NET 3.5
Install-WindowsFeature -Name Web-CGI             # CGI


# Health and Diagnostics 
Install-WindowsFeature -Name Web-Http-Logging
Install-WindowsFeature -Name Web-Log-Libraries
Install-WindowsFeature -Name Web-Request-Monitor
Install-WindowsFeature -Name Web-Http-Tracing # CONFIRMED: This name is correct.

# Security 
Install-WindowsFeature -Name Web-Basic-Auth
Install-WindowsFeature -Name Web-Digest-Auth
Install-WindowsFeature -Name Web-Windows-Auth

# Performance Features (Compression)
Install-WindowsFeature -Name Web-Stat-Compression
Install-WindowsFeature -Name Web-Dyn-Compression

# Management Tools 
Install-WindowsFeature -Name Web-Mgmt-Console # CONFIRMED: This is the correct name for IIS Management Console
Install-WindowsFeature -Name Web-Metabase
Install-WindowsFeature -Name Web-WMI
Install-WindowsFeature -Name Web-Lgcy-Mgmt-Console

# .NET Framework and WCF Features
Install-WindowsFeature -Name NET-Framework-Core # .NET 3.5
Install-WindowsFeature -Name NET-Http-Activation # HTTP Activation for .NET 3.5
Install-WindowsFeature -Name NET-Framework-45-Core # .NET 4.8 Core
Install-WindowsFeature -Name NET-Framework-45-ASPNET # ASP.NET 4.8
Install-WindowsFeature -Name NET-WCF-HTTP-Activation45 # WCF HTTP Activation for .NET 4.5
Install-WindowsFeature -Name NET-WCF-TCP-PortSharing45 # WCF TCP Port Sharing for .NET 4.5

# ===========================================
# Validate IIS Installation and Start Services
# ===========================================

$checkIIS = Get-WindowsFeature -Name Web-Server
if ($checkIIS.Installed -eq $true) {
    Write-Host "✅ IIS and selected features installed successfully."

    # Start IIS services
    Start-Service -Name W3SVC -ErrorAction SilentlyContinue
    Start-Service -Name IISADMIN -ErrorAction SilentlyContinue
    # Start FTP service
    Start-Service -Name FtpSvc -ErrorAction SilentlyContinue

    Write-Host "✅ IIS and FTP services started."
} else {
    Write-Host "❌ IIS installation failed."
}
