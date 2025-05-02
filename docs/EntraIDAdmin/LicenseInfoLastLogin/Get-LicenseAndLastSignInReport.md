# User License Report and LastSignIn Report

## Overview

This PowerShell script gathers mailbox information from Exchange Online and user license and sign-in information from Microsoft Entra ID (Azure AD) via Microsoft Graph API, and exports the results to a CSV report.

It supports:

- Filtering by mailbox type
- Reporting on:
  - Assigned licenses
  - Last sign-in and password change details
  - All combined details
- Efficient execution for large environments (10K+ users)

## Prerequisites

1. PowerShell 7.x+ (recommended)
2. Modules Required:
   - `ExchangeOnlineManagement`
   - `Microsoft.Graph` (v2.x or higher)

3. Permissions:
   - Exchange Online: Mailbox read access
   - Microsoft Graph:  
     `User.Read.All`, `Directory.Read.All`, `Organization.Read.All`, `RoleManagement.Read.All`

## 🚀 Key Features

- ✅ Efficient User Lookup: Uses hash table (`$userLookup`) to map UPNs and emails for fast lookups across 10k+ users.
- ✅ License Name Mapping: Dynamically downloads Microsoft's official license name mapping CSV. Falls back to local copy if the download fails.
- ✅ Combined Graph & Exchange Online Integration: Graph retrieves license data, sign-in activity, password change time. EXO retrieves mailbox creation/modification metadata.
- ✅ Clean CSV Output: Timestamped filenames. Three distinct report formats. Compatible with Excel, BI tools, and CSV importers.

## Report Output Columns

Depending on `-ReportType`, the report will include:

**AssignedLicenses:**

| DisplayName | UserPrincipalName | AssignedLicenses | LicenseCount | AssignedLicenseID | AssignedLicenseIDCount |

**LastSignInDetail:**

| DisplayName | UserPrincipalName | LastSignInTime | LastSignInDays | LastNonInteractiveSignInTime | LastNonInteractiveSignInDays | CreationTime | MailboxCreationTime | ModifiedObjectTime | LastPasswordChange |

**AllReportDetail:**

Includes all fields above, plus combined license and sign-in information.

## Sample Usage

Export a full report (all data) for user and shared mailboxes:

```powershell
.\Get-LicenseAndLastSignInReport.ps1 -RecipientTypes UserMailbox, SharedMailbox -ReportType AllReportDetail -ReportPath "C:\Reports"
```

License summary only:

```powershell
.\Get-LicenseAndLastSignInReport.ps1 -ReportType AssignedLicenses
```

Filtered by last sign-in:

```powershell
.\Get-LicenseAndLastSignInReport.ps1 -RecipientTypes UserMailbox -ReportType LastSignInDetail
```

## Parameters

### `-RecipientTypes` (Optional)

Mailbox types to include in the report.

| Value               | Description                      |
|--------------------|----------------------------------|
| `UserMailbox`       | Standard user mailboxes          |
| `SharedMailbox`     | Shared mailboxes                 |
| `RoomMailbox`       | Resource room mailboxes          |
| `EquipmentMailbox`  | Equipment resource mailboxes     |
| `SchedulingMailbox` | Scheduling/booking mailboxes     |
| `AllRecipientTypes` | All the above                    |

**Default**: `AllRecipientTypes`

### `-ReportType` (Optional)

Choose the report content type.

| Value              | Description                                      |
|-------------------|--------------------------------------------------|
| `AssignedLicenses` | Outputs license SKUs and friendly names          |
| `LastSignInDetail` | Outputs sign-in and password change details      |
| `AllReportDetail`  | Full report with all the above                   |

**Default**: `AllReportDetail`

### `-ReportPath` (Optional)

Path to save the report. Folder must be writable.

**Default**: `.` (current working directory)

### `-InactiveDaysThreshold` (Optional)

If set, filters users inactive for at least this many days based on last interactive sign-in.

**Example**: `-InactiveDaysThreshold 90` will return users who haven't signed in for 90+ days.

## Notes

- License Mapping CSV is downloaded from:  
  `https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv`

- Script handles null/missing users gracefully and logs such cases in memory.
