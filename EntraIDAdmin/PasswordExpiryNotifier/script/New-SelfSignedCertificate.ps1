<#
.SYNOPSIS
    Creates a self-signed certificate for use with Microsoft Entra ID (Azure AD) authentication.
.DESCRIPTION
    This script creates a self-signed certificate that can be used for:
    - Client credentials flow in OAuth
    - Service principal authentication
    - Certificate-based authentication in Microsoft Entra ID
    
    The script generates both a .pfx file (with private key) and a .cer file (public key only).
#>

param (
    [string]$CertificateName = "MGSelfSignedCert",
    [string]$OutputPath = ".\SSLCerts\",
    [int]$ValidForYears = 2,
    [string]$Password = "",
    [string]$Subject = "CN=MGSelfSignedCert"
)

# Check if output path exists, create if it doesn't
if (-not (Test-Path -Path $OutputPath)) {
    Write-Host "Creating output directory: $OutputPath"
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# Generate certificate
try {
    Write-Host "Creating self-signed certificate..."
    
    # Create secure password if provided
    $SecurePassword = $null
    if (-not [string]::IsNullOrEmpty($Password)) {
        $SecurePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
    }
    
    # Certificate parameters
    $certParams = @{
        Subject           = $Subject
        CertStoreLocation = "Cert:\CurrentUser\My"
        KeyExportPolicy   = "Exportable"
        KeySpec           = "Signature"
        KeyLength         = 2048
        KeyAlgorithm      = "RSA"
        HashAlgorithm     = "SHA256"
        NotAfter          = (Get-Date).AddYears($ValidForYears)
    }
    
    # Create certificate
    $cert = New-SelfSignedCertificate @certParams
    
    # Export paths
    $pfxPath = Join-Path -Path $OutputPath -ChildPath "$CertificateName.pfx"
    $cerPath = Join-Path -Path $OutputPath -ChildPath "$CertificateName.cer"
    
    # Export PFX with private key
    if ($SecurePassword) {
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $SecurePassword | Out-Null
    } else {
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $null | Out-Null
    }
    
    # Export CER (public key only)
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    
    Write-Host "`nCertificate created successfully!`n==========================================="
    Write-Host "PFX file (with private key): $pfxPath"
    Write-Host "CER file (public key only): $cerPath"
    
    # Display thumbprint (important for app registration)
    Write-Host "Certificate Thumbprint: $($cert.Thumbprint)"
    
    # Display additional information
    Write-Host "`nNext steps:`n==========================================="
    Write-Host "1. Upload the CER file to your Microsoft Entra app registration"
    Write-Host "2. Use the PFX file and thumbprint in your application configuration"
    Write-Host "3. The certificate will expire on: $($cert.NotAfter)"
    
    return $cert
}
catch {
    Write-Host "Error creating certificate: $_" -ForegroundColor Red
    exit 1
}