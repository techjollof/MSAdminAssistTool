<#
.SYNOPSIS
    Assigning phone numbers in bulk or for a single user and exporting the results to CSV file(s).
.DESCRIPTION
    This script assigns phone numbers to users or resource accounts based on CSV input or array data.
    It formats the phone number by ensuring it has the correct "+" prefix and exports the results to CSV.
.PARAMETER PhoneNumberType
    The phone number type: DirectRouting, CallingPlan, or OperatorConnect.
.PARAMETER UserIdCsv
    CSV file path containing user email and phone number, or an array of strings containing email and phone pairs.
.PARAMETER ReportPath
    The file path (including filename) where the export report will be saved. Defaults to PSScriptRoot if not specified.
.EXAMPLE 
    .\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting
.EXAMPLE 
    .\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting -UserIdCsv ".\Users.csv"
.EXAMPLE 
    .\Set-TeamsPhoneNumber.ps1 -PhoneNumberType DirectRouting -UserIdCsv @("+1234567890,john@demo.com", "jane@demo.com,+1987654321") -ReportPath "C:\Reports\MyReport.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("DirectRouting", "CallingPlan", "OperatorConnect")]
    [string]$PhoneNumberType,

    [Parameter()]
    [string]$UserIdCsv,

    [Parameter()]
    [string]$ReportPath
)

# Helper function to format phone numbers by adding a "+" if missing
function Format-PhoneNumber {
    param (
        [string]$PhoneNumber
    )
    
    # Add '+' if not present at the beginning of the phone number
    if ($PhoneNumber -notmatch '^\+') {
        return "+" + $PhoneNumber.Trim()
    }
    return $PhoneNumber.Trim()
}

$CompletedAndFailedObjects = @()

function Set-UserPhoneNumber {
    param (
        [string]$EmailAddress,
        [string]$PhoneNumber
    )

    $AssignmentResults = @()

    if (-not [string]::IsNullOrWhiteSpace($EmailAddress) -and -not [string]::IsNullOrWhiteSpace($PhoneNumber)) {
        Set-CsPhoneNumberAssignment -Identity $EmailAddress -EnterpriseVoiceEnabled $true -EA SilentlyContinue -EV LicenseUserError

        if ($LicenseUserError) {
            $AssignmentResults += [PSCustomObject]@{
                EmailAddress   = $EmailAddress
                PhoneNumber    = $PhoneNumber
                AssignStatus   = "Failed"
                FailureReason  = $LicenseUserError[0].ErrorDetails.Message
            }
        } else {
            Set-CsPhoneNumberAssignment -Identity $EmailAddress -PhoneNumber $PhoneNumber -PhoneNumberType $PhoneNumberType -EA SilentlyContinue -EV NumberAsignError

            $AssignmentResults += [PSCustomObject]@{
                EmailAddress   = $EmailAddress
                PhoneNumber    = $PhoneNumber
                AssignStatus   = if ($NumberAsignError) { "Failed" } else { "Succeeded" }
                FailureReason  = if ($NumberAsignError) { $NumberAsignError[0].ErrorDetails.Message } else { "Succeeded" }
            }
        }
    } else {
        Write-Host "Missing Email or Phone Number" -ForegroundColor Red
    }

    return $AssignmentResults
}

Write-Host "`n#### Assigning numbers... ####`n" -ForegroundColor Green

if ($UserIdCsv) {
    if ([System.IO.File]::Exists($UserIdCsv)) {
        # CSV file path is provided, read users from the file
        $Users = Import-Csv $UserIdCsv
    } elseif ($UserIdCsv -is [Array]) {
        # If an array of users is passed directly
        $Users = $UserIdCsv | ForEach-Object { 
            $phoneEmail = $_ -split ","
            
            # Format and swap values if necessary
            $formattedPhoneNumber = if ($phoneEmail[0] -match '^\+?\d{10,15}$') {
                Format-PhoneNumber -PhoneNumber $phoneEmail[0]
            } else {
                Format-PhoneNumber -PhoneNumber $phoneEmail[1]
            }

            [PSCustomObject]@{
                PhoneNumber  = $formattedPhoneNumber
                EmailAddress = $phoneEmail[0] -eq $formattedPhoneNumber ? $phoneEmail[1] : $phoneEmail[0]
            }
        }
    } else {
        Write-Host "Invalid UserIdCsv format or file not found: $UserIdCsv" -ForegroundColor Red
        exit 1
    }

    foreach ($user in $Users) {
        $results = Set-UserPhoneNumber -EmailAddress $user.EmailAddress -PhoneNumber $user.PhoneNumber
        $CompletedAndFailedObjects += $results
        Write-Host ("{0}`t{1}" -f $results[0].AssignStatus, $results[0].EmailAddress) -ForegroundColor DarkCyan
    }
} else {
    # Single user input if UserIdCsv is not provided
    $inputLine = Read-Host "Enter EmailAddress and PhoneNumber (e.g. john@demo.com,+11234567890)"
    $parts = $inputLine.Split(",").Trim()
    if ($parts.Length -eq 2) {
        $results = Set-UserPhoneNumber -EmailAddress $parts[0] -PhoneNumber $parts[1]
        $CompletedAndFailedObjects += $results
    } else {
        Write-Host "Invalid input format. Expected: email,phone" -ForegroundColor Red
        exit 1
    }
}

if ($ReportPath) {
    $CompletedAndFailedObjects | Export-Csv $ReportPath -NoTypeInformation
    Write-Host "`nResults exported to $ReportPath" -ForegroundColor Green
} else {
    Write-Host "`nNo report path provided. Skipping export." -ForegroundColor Yellow
}
