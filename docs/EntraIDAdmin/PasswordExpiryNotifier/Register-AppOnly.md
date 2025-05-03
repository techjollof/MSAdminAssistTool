# Register AppOnly

## Overview

This PowerShell script facilitates the creation and management of Azure App Registrations. It supports:

- Creating a new app registration with optional certificate-based authentication or a client secret.
- Updating an existing app registration by adding a new client secret or certificate.
- Exporting authentication details to a log file.



## Functionality

### Connecting to Microsoft Graph

The script connects to Microsoft Graph using the `Connect-MgGraph` cmdlet with `Application.ReadWrite.All` permissions. If a `TenantId` is provided, it explicitly connects to that tenant.

### Creating a New App Registration (`New-AppCreation`)

- Registers a new application in Azure AD.
- Creates a corresponding service principal.
- Assigns required Microsoft Graph API permissions.
- Generates and associates authentication credentials (client secret or certificate, if specified).

### Updating an Existing App Registration (`Update-AppAuthenticationMethods`)

- Retrieves the current authentication methods associated with the app.
- Updates the application with a new certificate (if provided via `CertPath`).
- Removes expired client secrets and generates a new secret if `CreateAppSecret` is specified.

### Exporting App Authentication Details

If an app registration is created or updated, its details (App ID, Tenant ID, authentication details) are exported to a log file in the script directory.

### Disconnecting from Microsoft Graph

By default, the script disconnects from Microsoft Graph after execution unless `-StayConnected` is specified.

## Example Usage

### Create a New App Registration

```powershell
.\AppRegistration.ps1 -AppName "MyNewApp" 
```

### Create a New App Registration with secret

```powershell
.\AppRegistration.ps1 -AppName "MyNewApp" -CreateAppSecret -TenantId "12345678-1234-1234-1234-123456789012"
```

### Create a New App Registration and Certificate 

```powershell
.\AppRegistration.ps1 -AppName "MyNewApp" -CreateAppSecret -CertPath "C:\Certs\mycert.cer" -TenantId "12345678-1234-1234-1234-123456789012"
```

### Update an Existing App Registration with a New Secret

```powershell
.\AppRegistration.ps1 -AppObjectId "abcdefab-1234-5678-9012-abcdefabcdef" -CreateAppSecret
```

### Update an Existing App Registration with a Certificate

```powershell
.\AppRegistration.ps1 -AppObjectId "abcdefab-1234-5678-9012-abcdefabcdef" -CertPath "C:\Certs\mycert.cer"
```

### Update an Existing App Registration with a Certificate and new secret

```powershell
.\AppRegistration.ps1 -AppObjectId "abcdefab-1234-5678-9012-abcdefabcdef" -CertPath "C:\Certs\mycert.cer"  -CreateAppSecret
```

## Error Handling

- If the script fails to connect to Microsoft Graph, it will return an error message.
- If an app name provided in `-AppName` already exists, the script will prompt the user to use `-AppObjectId` instead.
- If an invalid certificate is provided, the script will return an error.

## Logging

App registration details are saved in a file named `<AppName>_AppInfo.txt` in the script directory.

## Parameters

### `-AppName`

**Type:** String\
**Mandatory:** Yes (CreateApp mode)\
**Description:** The friendly name of the app registration.

### `-AppObjectId`

**Type:** GUID\
**Mandatory:** Yes (UpdateApp mode)\
**Description:** The unique identifier (object ID) of the existing app registration that should be updated.

### `-CertPath`

**Type:** String\
**Mandatory:** No\
**Description:** The file path to the public key certificate (.cer) to be associated with the app.

### `-CreateAppSecret`

**Type:** Switch\
**Mandatory:** No (CreateApp mode), Yes (UpdateApp mode)\
**Description:** Specifies whether a new client secret should be created.

### `-SecretDuration`

**Type:** Integer\
**Mandatory:** No\
**Default Value:** 6 (months)\
**Description:** The duration of the newly created client secret in months.

### `-TenantId`

**Type:** String\
**Mandatory:** No\
**Description:** The Azure Active Directory tenant ID. If omitted, the script attempts to determine the tenant context automatically.

### `-StayConnected`

**Type:** Switch\
**Mandatory:** No\
**Description:** Keeps the connection to Microsoft Graph active after script execution.


