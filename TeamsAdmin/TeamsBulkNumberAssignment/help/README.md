# Teams Phone Number Assignment

## Overview

This PowerShell script allows you to assign phone numbers to users in Microsoft Teams. You can assign phone numbers for a single user or in bulk using a CSV file or an array of email addresses and phone numbers. The results of the assignment process are exported to a CSV report file.

## Features

* Supports assigning phone numbers for **DirectRouting**, **CallingPlan**, and **OperatorConnect**.
* Supports bulk assignment via CSV file or array of email addresses and phone numbers.
* Automatically exports the results to a CSV report file.
* Handles errors during the assignment process and includes failure details in the report.
* Automatically formats phone numbers by ensuring a "+" prefix is present when needed.

## Prerequisites

* PowerShell 5.1 or later.
* Teams PowerShell module installed (`MicrosoftTeams`).
* User licenses for the phone number assignment (DirectRouting, CallingPlan, or OperatorConnect).
* The script requires administrative privileges to assign phone numbers.

## Script Workflow

1. **Single User Assignment**:
   If `UserIdCsv` is not provided, the script will prompt you to enter the email address and phone number for the user.

2. **Bulk User Assignment**:
   If `UserIdCsv` is provided, the script will read the CSV file or array and assign the phone numbers to the listed users. The CSV file should have the columns `EmailAddress` and `PhoneNumber`. If an array is provided, it should contain phone number and email pairs in the format `"phone,email"`.

3. **Error Handling**:
   If an error occurs during the assignment process (e.g., invalid phone number or license error), the failure details will be captured and included in the report.

4. **Report Generation**:
   The results of the assignments (success or failure) will be exported to a CSV report file. The report will contain the following columns:

   * `EmailAddress`: The user's email address.
   * `PhoneNumber`: The phone number assigned.
   * `AssignStatus`: Whether the assignment was successful or failed.
   * `FailureReason`: The reason for failure (if any).

## Usage

```powershell
.\Set-TeamsPhoneNumber.ps1 -PhoneNumberType <PhoneNumberType> [-UserIdCsv <CSVFilePath>] [-ReportPath <FilePath>]
```

* `<PhoneNumberType>`: Mandatory parameter. Choose from `DirectRouting`, `CallingPlan`, or `OperatorConnect`.
* `[-UserIdCsv <CSVFilePath>]`: Optional. Provide a CSV file for bulk assignment, it can also be an array, check example 4
* `[-ReportPath <FilePath>]`: Optional. Provide a path for exporting the results to a CSV file.

## Examples

### Example 1: Assigning a phone number to a single user

```powershell
.\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting
```

This will prompt you to enter the user's email address and phone number.

### Example 2: Assigning phone numbers in bulk from a CSV file

```powershell
.\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting -UserIdCsv ".\Users.csv"
```

This will read the `Users.csv` file and assign phone numbers for the users listed in the file.

### Example 3: Assigning phone numbers with a custom report path

```powershell
.\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting -UserIdCsv ".\Users.csv" -ReportPath "C:\Reports\PhoneNumberAssignment.csv"
```

This will assign phone numbers from the `Users.csv` file and export the results to `C:\Reports\PhoneNumberAssignment.csv`.

### Example 4: Assigning phone numbers with array input

```powershell
.\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting -UserIdCsv @("+1234567890,john@demo.com", "jane@demo.com,+1987654321") -ReportPath "C:\Reports\PhoneNumberAssignment.csv"
```

This example assigns phone numbers to users using an array of phone number and email pairs, and exports the results to a specified file.

## Parameters

### `PhoneNumberType` (Mandatory)

* **Type**: `String`
* **Description**: Specifies the type of phone number assignment.
* **Valid values**: `"DirectRouting"`, `"CallingPlan"`, `"OperatorConnect"`

### `UserIdCsv` (Optional)

* **Type**: `String` or `Array`
* **Description**: The path to a CSV file containing the user email addresses and phone numbers or an array of user information.

  * If a CSV file is provided, it should contain two columns: `EmailAddress` and `PhoneNumber`.
  * If an array is provided, the format should be `"phone,email"`.
* **Example CSV format**:

```csv
EmailAddress,PhoneNumber
user1@example.com,+11234567890
user2@example.com,+11234567891
```

### `ReportPath` (Optional)

* **Type**: `String`
* **Description**: The file path (including filename) for exporting the results to a CSV file. Defaults to `$PSScriptRoot\PhoneNumberAssignmentReport.csv` if not provided.
* **Example**: `"C:\Reports\PhoneNumberAssignment.csv"`

## Error Handling

* If the email address or phone number is missing, the script will display an error message.
* If the phone number assignment fails (due to licensing or other errors), the failure details will be recorded in the report.
* The script gracefully handles errors during bulk assignments and logs the results for each user.

## Output Report

The output report generated by the script will include the following columns:

* `EmailAddress`: The email address of the user.
* `PhoneNumber`: The phone number assigned to the user.
* `AssignStatus`: Whether the assignment succeeded or failed.
* `FailureReason`: The reason for failure (if any).

	![Sample Report](images/Sample%20Results.png)

## Troubleshooting

* **Missing or Invalid CSV File**: Ensure the file path provided in the `UserIdCsv` parameter is correct and that the file is accessible.
* **Invalid Phone Number Type**: Ensure that you have selected one of the valid phone number types (`DirectRouting`, `CallingPlan`, or `OperatorConnect`).
* **Licensing Issues**: Ensure that the users have the appropriate Teams Phone System license assigned before attempting the phone number assignment.
* **Incorrect Phone Number Format**: Ensure that phone numbers are provided in the correct international format (with or without the "+" prefix).

## Contact and Support

For further assistance or issues with the script, please reach out to [techjollof@gmail.com](mailto:techjollof@gmail.com) or visit the issue page [Raise Issue](https://github.com/techjollof/MSAdminAssistTool/issues)
