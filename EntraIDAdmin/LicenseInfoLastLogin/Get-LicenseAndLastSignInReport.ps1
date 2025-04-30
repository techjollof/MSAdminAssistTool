<#
.SYNOPSIS
Generates detailed Exchange Online and Microsoft Entra ID reports for users, including license assignment, sign-in activity, and mailbox details.

.PARAMETER RecipientTypes
(Optional) Specifies which mailbox types to include in the report.

Valid values:
- UserMailbox         : Standard user mailboxes
- SharedMailbox       : Shared mailboxes
- RoomMailbox         : Resource room mailboxes
- EquipmentMailbox    : Equipment resource mailboxes
- SchedulingMailbox   : Scheduling/booking mailboxes
- AllRecipientTypes   : All the above types

Default: AllRecipientTypes

.PARAMETER ReportType
(Optional) Determines the type of report to generate.

Valid values:
- AssignedLicenses    : Outputs license SKUs and friendly names
- LastSignInDetail    : Outputs sign-in and password change details
- AllReportDetail     : Full report with all the above information

Default: AllReportDetail

.PARAMETER ReportPath
(Optional) File system path where the report CSV will be saved.

Note: The folder must be writable.
Default: Current directory (".")

.PARAMETER InactiveDaysThreshold
(Optional) Filters users who have been inactive (based on last interactive sign-in) for at least this many days.

Example:
-InactiveDaysThreshold 90
Returns only users who haven't signed in for 90 or more days.

#>


[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Choose mailbox types: EquipmentMailbox, RoomMailbox, SchedulingMailbox, SharedMailbox, UserMailbox, AllRecipientTypes")]
    [ValidateSet("EquipmentMailbox", "RoomMailbox", "SchedulingMailbox", "SharedMailbox", "UserMailbox", "AllRecipientTypes")]
    [string[]] $RecipientTypes = "AllRecipientTypes",

    [Parameter()]
    [ValidateSet("AssignedLicenses", "LastSignInDetail", "AllReportDetail")]
    [string] $ReportType = "AllReportDetail",

    [Parameter()]
    [string] $ReportPath = ".",

    [Parameter(HelpMessage = "Number of days of inactivity to filter users (e.g., 90 means users inactive for 90+ days).")]
    [int]
    $InactiveDaysThreshold
)

# Exchange Online connection
if (-not (Get-Command Get-OrganizationConfig -ErrorAction SilentlyContinue)) {
    if (Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue) {
        Connect-ExchangeOnline -ShowBanner:$false
    }
    else {
        Write-Warning "Exchange Online module not found. Please install and connect manually."
    }
}

# Microsoft Graph connection
if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
    Write-Warning "Microsoft Graph module not found. Please install and connect manually."
}
else {
    try {
        Get-MgUser -Top 1 -ErrorAction Stop | Out-Null
    }
    catch {
        Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"
    }
}

# Get mailboxes
Write-Host "`nGetting exchange mailbox box information..." -ForegroundColor Yellow
$mailboxes = if ($RecipientTypes -eq "AllRecipientTypes") {
    Get-Mailbox -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -ne "DiscoveryMailbox" }
}
else {
    Get-Mailbox -RecipientTypeDetails $RecipientTypes -ResultSize Unlimited | Where-Object { $_.RecipientTypeDetails -ne "DiscoveryMailbox" }
}

# Get users and build fast lookup table
Write-Host "Indexing Entra ID users..." -ForegroundColor Yellow
$allUsers = Get-MgUser -All -Property UserPrincipalName, Mail, AccountEnabled, DisplayName, LicenseAssignmentStates, SignInActivity, LastPasswordChangeDateTime
$userLookup = @{}
foreach ($user in $allUsers) {
    if ($user.UserPrincipalName) { $userLookup[$user.UserPrincipalName.ToLower()] = $user }
    if ($user.Mail) { $userLookup[$user.Mail.ToLower()] = $user }
}

# Get licenses
$tenantSkus = Get-MgSubscribedSku -All
$skuLookup = @{}
foreach ($sku in $tenantSkus) {
    $skuLookup[$sku.SkuId] = $sku
}

# Download license-friendly names
$licenseUrl = "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv"
$licenseFile = Join-Path -Path $PSScriptRoot -ChildPath "LicenseFriendlyNames.csv"

try {
    Invoke-RestMethod -Uri $licenseUrl -OutFile $licenseFile -ErrorAction Stop
    Write-Host "Downloaded license names." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to download license file. Trying local copy."
}

$licenseLookup = @{}
if (Test-Path $licenseFile) {
    Import-Csv $licenseFile | ForEach-Object {
        if ($_.GUID -and !$licenseLookup.ContainsKey($_.GUID)) {
            $licenseLookup[$_.GUID] = $_
        }
    }
}

# Prepare result list
$results = [System.Collections.Generic.List[object]]::new()
$counter = 0
$totalUsers = ($mailboxes | Measure-Object).Count
$nextMilestone = 10


Write-Host "`nProcessing report for users..." -ForegroundColor Yellow
foreach ($mbx in $mailboxes) {

    $counter++
    $percentComplete = [math]::Floor(($counter / $totalUsers) * 100)


    $key = $mbx.UserPrincipalName.ToLower()
    $entraUser = $userLookup[$key]
    if (-not $entraUser) {
        $entraUser = $userLookup[$mbx.PrimarySmtpAddress.ToLower()]
    }

    $lastSignIn = $entraUser.SignInActivity.LastSignInDateTime
    $lastSignInDays = if ($lastSignIn) { (Get-Date) - $lastSignIn } else { $null }

    $lastNonInteractive = $entraUser.SignInActivity.LastNonInteractiveSignInDateTime
    $lastNonInteractiveDays = if ($lastNonInteractive) { (Get-Date) - $lastNonInteractive } else { $null }

    $licenseIDs = @()
    $licenseNames = @()
    if ($entraUser.LicenseAssignmentStates) {
        foreach ($skuId in $entraUser.LicenseAssignmentStates.SkuId) {
            $licenseIDs += $skuLookup[$skuId]?.SkuPartNumber
            $licenseNames += $licenseLookup[$skuId]?.Product_Display_Name
        }
        $licenseNames = $licenseNames | Sort-Object -Unique
    }

    $results.Add([PSCustomObject]@{
            UserPrincipalName            = $mbx.UserPrincipalName
            DisplayName                  = $mbx.DisplayName
            CreationTime                 = $mbx.WhenCreated
            MailboxCreationTime          = $mbx.WhenMailboxCreated
            ModifiedObjectTime           = $mbx.WhenChanged
            MailboxType                  = $mbx.RecipientTypeDetails
            AccountEnabled               = $entraUser.AccountEnabled
            LastSignInTime               = $null -ne $lastSignIn ? $lastSignIn : 'Never Logged in'
            LastSignInDays               = $lastSignInDays.Days
            LastNonInteractiveSignInTime = $null -ne $lastNonInteractive ? $lastNonInteractive : 'Never Logged in'
            LastNonInteractiveSignInDays = $lastNonInteractiveDays.Days
            AssignedLicenses             = if ($licenseNames) { $licenseNames -join ',' } else { 'No Assigned License' }
            LicenseCount                 = $licenseNames.Count
            AssignedLicenseID            = $licenseIDs -join ','
            AssignedLicenseIDCount       = $licenseIDs.Count
            LastPasswordChange           = $entraUser.LastPasswordChangeDateTime
        })


    while ($percentComplete -ge $nextMilestone) {
        Write-Host "Progress: $nextMilestone% complete. Processed $counter of $totalUsers users..." -ForegroundColor Cyan
        $nextMilestone += 10
    }
}

# Filter inactive users if threshold is set
if ($PSBoundParameters.ContainsKey('InactiveDaysThreshold')) {
    Write-Host "`n`tFiltering users who haven't signed in for $InactiveDaysThreshold days..." -ForegroundColor Yellow
    $results = $results | Where-Object {
        ($_.LastSignInDays -ne '' -and $_.LastSignInDays -ge $InactiveDaysThreshold)
    }
}

# Export
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory | Out-Null
}
$timestamp = Get-Date -Format "MM-dd-yyyy HH-mm"
$outputPath = Join-Path -Path $ReportPath -ChildPath "UserReport $timestamp.csv"

Write-Host "`nExporting report to: $outputPath" -ForegroundColor Cyan

switch ($ReportType) {
    'AssignedLicenses' {
        $results |
        Select-Object DisplayName, UserPrincipalName, AssignedLicenses, LicenseCount, AssignedLicenseID, AssignedLicenseIDCount |
        Export-Csv -Path $outputPath -NoTypeInformation
    }
    'LastSignInDetail' {
        $results |
        Select-Object DisplayName, UserPrincipalName, LastSignInTime, LastSignInDays, LastNonInteractiveSignInTime, LastNonInteractiveSignInDays, CreationTime, MailboxCreationTime, ModifiedObjectTime, LastPasswordChange |
        Export-Csv -Path $outputPath -NoTypeInformation
    }
    default {
        $results | Export-Csv -Path $outputPath -NoTypeInformation
    }
}
