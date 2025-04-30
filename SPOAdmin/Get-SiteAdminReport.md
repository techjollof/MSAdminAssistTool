# SPO and OneDrive Site Collection Administrator Report Generator

## SYNOPSIS

Generates a detailed report of SharePoint Online (SPO) and OneDrive site collection administrators.  
The script automates permission management to retrieve site admin data securely and efficiently.

## DESCRIPTION

Normally, to retrieve site administrator details using `Get-SPOUser`, you must already be a site collection administrator.  
This script automates the entire process by:

1. Granting temporary admin permissions to the specified account.
2. Retrieving the required site collection admin information.
3. Removing the temporary permissions after the retrieval is complete.

The account used for `Connect-SPOService` must have **Global Admin** or **SharePoint Online Admin** rights.

Additionally, the script ensures:

- Auto-loading of required modules if missing.
- Auto-connection to SharePoint if disconnected.
- Reports are consistently exported to the script's directory.

## HOW TO USE THIS SCRIPT

### Step 1: Download and Extract

Download the script and extract it into a local folder.

**Example Path:**

```plaintext
C:\Users\NAME\Downloads\SPOandOneDriveSiteAdminReportGenerator
```

This path corresponds to:

```powershell
$PSScriptRoot
```

within the script.

### Step 2: Open PowerShell and Navigate to the Script Directory

```powershell
cd C:\Users\NAME\Downloads\SPOandOneDriveSiteAdminReportGenerator
```

### Step 3: Connect to SharePoint Online

Connect manually before running the script **OR** let the script auto-connect (if `TenantUrl` is provided):

```powershell
Connect-SPOService -Url https://TENANTNAME-admin.sharepoint.com
```

> Replace `TENANTNAME` with your actual tenant name.

### Step 4: Run the Script

#### Example 1: Generate a Report for All Sites

```powershell
.\Get-SiteAdminReport.ps1 -GlobalSPOAdminAddress techjollof@contoso.com -TenantUrl https://TENANTNAME-admin.sharepoint.com
```

#### Example 2: Generate a Report for OneDrive Sites Only

```powershell
.\Get-SiteAdminReport.ps1 -GlobalSPOAdminAddress techjollof@contoso.com -TenantUrl https://TENANTNAME-admin.sharepoint.com -SiteAdminReportType OneDriveOnly
```

## PARAMETERS

### **GlobalSPOAdminAddress**

- **Description**: Email address of the account used to temporarily gain site collection admin access and retrieve site admin information.
- **Mandatory**: Yes
- **Important**: Must match the account used for `Connect-SPOService`.

### **TenantUrl**

- **Description**: Your SharePoint Admin Center URL (e.g., `https://TENANTNAME-admin.sharepoint.com`).
- **Mandatory**: Yes if auto-connection is needed. Otherwise optional if already connected.

### **SiteAdminReportType**

- **Description**: Limits report to specific site types. Options include:
  - `OneDriveOnly`
  - `SharedChannelSiteOnly`
  - `PrivateChannelSiteOnly`
  - `CommunicationSiteOnly`
  - `AllTeamsSiteOnly`
  - `ParentTeamSiteOnly`
  - `ClassicSiteOnly`
- **Default**: If not specified, includes all sites.

## REPORT OUTPUT

- The report is automatically saved as a `.csv` file in the same folder where the script is located.
- File name format:  
  `SiteCollectionAdministrator_Report_for_<SiteType>.csv`
  
  Example:  
  `SiteCollectionAdministrator_Report_for_OneDriveOnly.csv`

- Path construction uses `$PSScriptRoot` internally for reliability across environments.

## TROUBLESHOOTING: Empty Export File

If the exported `.csv` file is unexpectedly empty while you can still see results in PowerShell, the script can fallback to exporting the data to Excel (`.xlsx`) format.

**Install ImportExcel module manually (if needed):**

```powershell
Install-Module ImportExcel -AllowClobber -Force -Scope CurrentUser
```

This ensures you have the `Export-Excel` command available for advanced exporting.

## 💡 ADDITIONAL FEATURES

- **Automatic Module Import**: If `Microsoft.Online.SharePoint.PowerShell` is not available, it gets imported dynamically.
- **Automatic SPO Connection**: If disconnected or permission errors occur, the script attempts to reconnect.
- **Clean Admin Management**: Temporary admin permissions are revoked after retrieving data.

## 📈 ADDITIONAL RESOURCES

- [Get-SPOSite](https://learn.microsoft.com/en-us/powershell/module/sharepoint-online/get-sposite?view=sharepoint-ps)
- [Get-SPOUser](https://learn.microsoft.com/en-us/powershell/module/sharepoint-online/get-spouser?view=sharepoint-ps)
- [Connect to SharePoint Online PowerShell](https://learn.microsoft.com/en-us/powershell/sharepoint/sharepoint-online/connect-sharepoint-online)

## 👍 FEEDBACK

If you find this script helpful, please feel free to **share**, **like**, and **comment**.  
Feedback and contributions are always welcome to improve the project further.

## 🔥 IMPROVEMENTS MADE

1. **$PSScriptRoot Usage**: Ensures exports are placed reliably next to the script.
2. **Fallback for Missing Commands**: Dynamically imports modules and connects if needed.
3. **Better Path Handling**: Uses `Join-Path` instead of raw string paths.
4. **Clear Error Messages**: Easier troubleshooting when not connected or lacking permissions.
5. **Consistent Export Naming**: Standardized CSV file naming conventions based on site types.
