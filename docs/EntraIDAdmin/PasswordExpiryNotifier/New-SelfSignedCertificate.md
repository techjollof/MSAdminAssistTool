# Self-Signed Certificate Generation

## Overview

This PowerShell script generates a self-signed certificate for use with Microsoft Entra ID (Azure AD) authentication. The script creates both a `.pfx` file (containing the private key) and a `.cer` file (public key only).

## Purpose

The generated certificate can be used for:

- OAuth client credentials flow
- Service principal authentication
- Certificate-based authentication in Microsoft Entra ID

## Prerequisites

- PowerShell 5.1 or later
- Administrator privileges (if needed for certificate installation)

## Functionality

### Creating the Self-Signed Certificate

- The script checks if the specified output directory exists; if not, it creates the directory.
- A self-signed certificate is generated using RSA 2048-bit encryption and SHA-256 hashing.
- The certificate is stored in the `Cert:\CurrentUser\My` store.

### Exporting Certificate Files

- A `.pfx` file (private key) is exported, optionally password-protected.
- A `.cer` file (public key only) is exported for use in Microsoft Entra ID.

## Example Usage

### Generate a Certificate with Default Parameters

```powershell
.\CreateSelfSignedCertificate.ps1
```

### Generate a Certificate with a Custom Name and Path

```powershell
.\CreateSelfSignedCertificate.ps1 -CertificateName "MyAppCert" -OutputPath "C:\Certs" -ValidForYears 3
```

### Generate a Password-Protected Certificate

```powershell
.\CreateSelfSignedCertificate.ps1 -Password "SecurePass123!"
```

## Next Steps

1. Upload the `.cer` file to your Microsoft Entra app registration.
2. Use the `.pfx` file and thumbprint in your application configuration.
3. Ensure the certificate is renewed before expiration to avoid service disruptions.

## Logging

The script outputs key details such as:

- Certificate paths (`.pfx` and `.cer`)
- Certificate thumbprint
- Expiration date

## Parameters

### `-CertificateName`

**Type:** String  
**Default Value:** `MGSelfSignedCert`  
**Description:** The name of the certificate to be generated. This name is used for output file naming.

### `-OutputPath`

**Type:** String  
**Default Value:** `.` (current directory)  
**Description:** The directory where the certificate files will be saved.

### `-ValidForYears`

**Type:** Integer  
**Default Value:** `2`  
**Description:** The validity duration of the certificate in years.

### `-Password`

**Type:** String  
**Default Value:** `""` (empty)  
**Description:** Optional password for the `.pfx` file. If not specified, the private key will not be password-protected.

### `-Subject`

**Type:** String  
**Default Value:** `CN=MGSelfSignedCert`  
**Description:** The subject name of the certificate.

## Error Handling

- If the script fails to create a certificate, an error message is displayed.
- If an invalid output path is specified, the script attempts to create the directory.
- If the certificate creation process encounters issues, the script exits with an error message.
