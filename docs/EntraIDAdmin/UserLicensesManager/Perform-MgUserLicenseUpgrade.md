# Perform-MgUserLicenseUpgrade

## Overview

The `Perform-MgUserLicenseUpgrade` script is designed to **migrate Microsoft 365 users from one license SKU to another**, supporting optional **disabling of specific service plans**, interactive GUI-based SKU selection, and advanced CSV parsing. It uses the Microsoft Graph PowerShell SDK.

---

## 🚀 Features

- Migrate users from one SKU to another.
- Disable selected service plans (e.g., Exchange, Yammer).
- Process single UPNs or bulk users via CSV, or combine csv + UPNs input.
- Interactive license picker using `Out-GridView`.
- Intelligent CSV detection (structured/unstructured).
- Retains existing disabled service plans (optional).
- Full logging to timestamped and persistent log files.

## 📂 Prerequisites

- **Modules Required**:  
  `Microsoft.Graph.Users`, `Microsoft.Graph.Authentication`  
  (Install using: `Install-Module Microsoft.Graph -Scope CurrentUser`)

- **Authentication**:  
  You must be connected via `Connect-MgGraph` before running the script.

- **Permissions Needed**:
  - `User.Read.All`
  - `User.ReadWrite.All`
  - `Directory.Read.All`
  - `Directory.AccessAsUser.All`



## 📌 [Parameters](/EntraIDAdmin/UserLicensesManager/#📚-parameter-details)

| **Parameter**                | **Type**       | **Required** | **Description**                                                                |
| ---------------------------- | -------------- | ------------ | ------------------------------------------------------------------------------ |
| [`-UserIds`](/EntraIDAdmin/UserLicensesManager/#userids)        | `string[]`     | ✅           | UPN(s) or path(s) to CSV file(s) containing user identifiers. It also takes direct userIds like "user@contoso.dev", "user1@contoso.dev", or a mixture of CSV file and direct UPNs.              |
| [`-LicenseToRemove`](/EntraIDAdmin/UserLicensesManager/#licensetoremove) | `string`       | ✅*          | SKU part number to remove (e.g., `SPE_E3`).                                    |
| [`-LicenseToAdd`](/EntraIDAdmin/UserLicensesManager/#licensetoadd)        | `string`       | ✅*          | SKU part number to assign (e.g., `SPE_E5`).                                    |
| [`-DisabledPlans`](/EntraIDAdmin/UserLicensesManager/#disabledplans)       | `string[]`     | ❌           | Array of service plan GUIDs to disable in the new license.                     |
| [`-SelectLicense`](/EntraIDAdmin/UserLicensesManager/#SelectLicense)       | `switch`       | ❌           | Enables interactive selection of licenses using GUI.                           |
| [`-SelectDisabledPlans`](/EntraIDAdmin/UserLicensesManager/#SelectDisabledPlans)        | `switch`       | ❌           | Launch GUI to select which service plans to disable.                           |
| [`-KeepExistingPlanState`](/EntraIDAdmin/UserLicensesManager/#keepexistingplanstate) | `switch`       | ❌           | Retain user’s existing disabled plan settings, if compatible with new SKU.     |

> ⚠️ `LicenseToRemove` and `LicenseToAdd` are **not required** when `-SelectLicense` is used.

## 📄 CSV Format Examples

### 🔹 Structured CSV

```csv
UserPrincipalName,Department
alice@contoso.dev,Sales
bob@contoso.dev,IT
```

### 🔹 Unstructured CSV

```csv
alice@contoso.dev
bob@contoso.dev
```

### 🔹 Mix data 

UPN(s) or path(s) to CSV file(s) containing user identifiers. It also takes direct userIds like "user@contoso.dev", "user1@contoso.dev", or a mixture of CSV file and direct UPNs.

> The script auto-detects whether the file is structured or not and intelligently selects the most likely user identifier column.

## 💡 Examples

### Migrate a single user from E3 to E5

```powershell
Perform-MgUserLicenseUpgrade -UserIds "alice@contoso.dev" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5"
```

### Combining a mixture array of users or single or array of user and CSV file to Migrate users from E3 to E5

```powershell
Perform-MgUserLicenseUpgrade -UserIds "alice@contoso.dev","admam@contoso.dev" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5"
```

```powershell
Perform-MgUserLicenseUpgrade -UserIds "alice@contoso.dev","admam@contoso.dev", "c:\temp\licenseUpgrade.csv" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5"
```

```powershell
Perform-MgUserLicenseUpgrade -UserIds "alice@contoso.dev","c:\temp\licenseUpgrade.csv" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5"
```

### Bulk migration from CSV with same SKU upgrade

```powershell
Perform-MgUserLicenseUpgrade -UserIds ".\users.csv" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5"
```

### Interactive license picker with GUI

```powershell
Perform-MgUserLicenseUpgrade -UserIds ".\users.csv" -SelectLicense
```

### Disable specific service plans during migration

```powershell
Perform-MgUserLicenseUpgrade -UserIds "alice@contoso.dev" -LicenseToRemove "SPE_E3" -LicenseToAdd "SPE_E5" -DisabledPlans "e95bec33-7c88-4a70-8e19-b10bd9d0c05b"
```

### Combine plan picker and plan state retention

```powershell
Perform-MgUserLicenseUpgrade -UserIds ".\users.csv" -SelectLicense -SelectDisabledPlans -KeepExistingPlanState
```

## 🧾 Logging

- Log files are stored under:  
  `.\Logs\LicenseUpgrade_yyyy-MM-dd.log`  
  and  
  `.\LicenseChange.log`

- Message types:
  - `INFO`: General operations
  - `WARNING`: Partial user-specific issues
  - `ERROR`: Failures and exceptions
  - `DRYRUN`: Simulated output when `ShouldProcess` not confirmed

## 🔍 Internal Logic Flow

1. **Validate parameters and modules.**
2. **Read and process user list from UPN or CSV file.**
3. **Fetch available subscribed SKUs.**
4. **Pick or match SKUs (interactive or direct).**
5. **Determine disabled service plans.**
6. **Validate users and collect current license info.**
7. **Perform license removal, followed by assignment.**
8. **Log each step with status.**

## ⚙️ Known Limitations

- GUI components (`Out-GridView`) are not supported in non-interactive sessions (e.g., scheduled tasks).
- Service plan disabling relies on exact `ServicePlanId` or `ServicePlanName`.
- Users must already exist in Microsoft 365 and have valid UPNs.

## 🧪 Testing and Validation

| Test Case                      | Expected Result                          |
| ------------------------------ | ---------------------------------------- |
| Valid single UPN               | License updated, log entry created       |
| Invalid CSV                    | Warning logged, skips that file          |
| Empty `DisabledPlans`          | License applied with all plans enabled   |
| Duplicate users in input       | Deduplicated before processing           |
| Invalid `LicenseToAdd` SKU     | Error logged, no change made             |
| Interactive mode + plan picker | Correct plans disabled per GUI selection |

## 📚 Parameter Details

#### `-UserIds`

- **Type**: `string[]`
- **Description**: Accepts a single UPN (user principal name) or a path to a CSV file containing user identifiers (UPNs). Multiple UPNs can be passed as an array.
- **Valid Values**: A single UPN, a list of UPNs, or the path to a CSV file containing UPNs.
- **Example**:
  - `"alice@contoso.dev"`
  - `".\users.csv"`

#### `-LicenseToRemove`

- **Type**: `string`
- **Description**: Specifies the SKU part number of the license to be removed from the user(s).
- **Valid Values**: Any valid Microsoft 365 license part number, such as:
  - `SPE_E3` (Microsoft 365 Business Standard)
  - `SPE_E5` (Microsoft 365 Business Premium)
- **Example**: `"SPE_E3"`

#### `-LicenseToAdd`

- **Type**: `string`
- **Description**: Specifies the SKU part number of the new license to be assigned to the user(s).
- **Valid Values**: Any valid Microsoft 365 license part number, such as:
  - `SPE_E5`
  - `SPE_F3`
- **Example**: `"SPE_E5"`

#### `-DisabledPlans`

- **Type**: `string[]`
- **Description**: Optional. Specifies an array of service plan GUIDs that should be disabled in the new license.
- **Valid Values**: Array of valid GUIDs representing service plans, e.g., Exchange, Yammer, etc. These GUIDs can be fetched using Microsoft Graph or other means.
- **Example**: `("e95bec33-7c88-4a70-8e19-b10bd9d0c05b")`

#### `-SelectLicense`

- **Type**: `switch`
- **Description**: Enables interactive license selection through a graphical user interface (GUI) via `Out-GridView`.
- **Valid Values**: `$true` or `$false` (default is `$false`).
- **Example**: `-SelectLicense`

#### `-SelectDisabledPlans`

- **Type**: `switch`
- **Description**: If set, it allows for the selection of specific service plans to disable during license assignment through a GUI.
- **Valid Values**: `$true` or `$false` (default is `$false`).
- **Example**: `-SelectDisabledPlans`

#### `-KeepExistingPlanState`

- **Type**: `switch`
- **Description**: When set to `$true`, the script will retain the user’s existing disabled plans when assigning the new license. This allows you to preserve the state of already disabled service plans, preventing the need to disable them again.
- **Valid Values**: `$true` or `$false` (default is `$false`).
- **Example**: `-KeepExistingPlanState`
