# SPO and OneDrive Site Collection Administrator Report Generator

<#
.SYNOPSIS
    Generate SPO/OneDrive site administrators report.

.DESCRIPTION
    This script automates the retrieval of SharePoint Online (SPO) and OneDrive site collection administrators. 
    It temporarily grants admin access to the specified account, gathers the required data using Get-SPOUser, 
    and then removes the temporary permissions. The account used must be a Global or SharePoint Online Administrator.

.PARAMETER GlobalSPOAdminAddress
    The email address of the account that will be temporarily granted site collection admin permissions. 
    This should be the same account used to connect via Connect-SPOService.

.PARAMETER TenantUrl
    The full URL of the SharePoint Online admin center (e.g., https://tenantname-admin.sharepoint.com). 
    Required if not already connected.

.PARAMETER SiteAdminReportType
    Specifies the type of sites to include in the report. Available options:
        - OneDriveOnly
        - SharedChannelSiteOnly
        - PrivateChannelSiteOnly
        - CommunicationSiteOnly
        - AllTeamsSiteOnly
        - ParentTeamSiteOnly
        - ClassicSiteOnly
    If not specified, the report will include all SPO and OneDrive sites.

.EXAMPLE
    .\GetSPOandOneDriveSiteAdminReport.ps1 -GlobalSPOAdminAddress techjollof@contoso.com -SiteAdminReportType OneDriveOnly

.EXAMPLE
    .\GetSPOandOneDriveSiteAdminReport.ps1 -GlobalSPOAdminAddress techjollof@contoso.com
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GlobalSPOAdminAddress,

    [Parameter()]
    [string]$TenantUrl,

    [Parameter()]
    [ValidateSet("OneDriveOnly", "SharedChannelSiteOnly", "PrivateChannelSiteOnly", "CommunicationSiteOnly", "AllTeamsSiteOnly", "ParentTeamSiteOnly", "ClassicSiteOnly")]
    [string]$SiteAdminReportType
)

function Write-Result {
    param (
        [string]$TextData,
        [switch]$IsError,
        [string]$Color = "Yellow"
    )
    if ($IsError) {
        Write-Host $TextData -ForegroundColor Red
    } else {
        Write-Host $TextData -ForegroundColor $Color
    }
}

# Check if the Get-SPOUser command is available
if (-not (Get-Command Get-SPOUser -ErrorAction SilentlyContinue)) {
    if (-not $TenantUrl) {
        throw "Not connected to SharePoint Online. Please connect using Connect-SPOService or provide the -TenantUrl parameter."
    }

    Write-Host "Importing SharePoint Online PowerShell module..." -ForegroundColor Cyan
    Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell -WarningAction SilentlyContinue

    Write-Host "Connecting to SharePoint Online using Tenant URL: $TenantUrl" -ForegroundColor Cyan
    try {
        Connect-SPOService -Url $TenantUrl
    } catch {
        throw "Failed to connect to SharePoint Online: $_"
    }
} else {
    try {
        # Attempt a harmless command to confirm connection
        Get-SPOSite -Limit 1 -ErrorAction Stop | Out-Null
    } catch {
        if (-not $TenantUrl) {
            throw "It appears you're not connected to SharePoint Online and -TenantUrl is not provided."
        }

        Write-Host "Reconnecting to SharePoint Online using Tenant URL: $TenantUrl" -ForegroundColor Cyan
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
        try {
            Connect-SPOService -Url $TenantUrl
        } catch {
            throw "Failed to connect to SharePoint Online: $_"
        }
    }
}


$AllSPOSites = Get-SPOSite -IncludePersonalSite:$true -Limit All

switch ($SiteAdminReportType) {
    "OneDriveOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -eq "SPSPERS#10" } }
    "SharedChannelSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -like "TEAMCHANNEL*" -and $_.TeamsChannelType -eq "SharedChannel" } }
    "PrivateChannelSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -like "TEAMCHANNEL*" -and $_.TeamsChannelType -eq "PrivateChannel" } }
    "CommunicationSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -eq "SITEPAGEPUBLISHING#0" } }
    "AllTeamsSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -in "GROUP#0", "TEAMCHANNEL#0", "TEAMCHANNEL#1" } }
    "ParentTeamSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -eq "GROUP#0" } }
    "ClassicSiteOnly" { $SPOSiteURL = $AllSPOSites | Where-Object { $_.Template -in "STS#0", "STS#1", "STS#2", "STS#3" } }
    default { $SPOSiteURL = $AllSPOSites }
}

$SiteOwnerResults = @()
$ProgressCount = 0

Write-Result "Retrieving site collection administrators"

foreach ($SiteURL in $SPOSiteURL) {
    $ProgressCount++

    try {
        $SiteCollectionAdmins = Get-SPOUser -Site $SiteURL.Url -ErrorVariable NoAdminAccess -ErrorAction SilentContinue | Where-Object { $_.IsSiteAdmin } 
        # Write-Result "`n$GlobalSPOAdminAddress already has admin access to $($SiteURL.Url)" -Color "Green"
    }
    catch {
        # Write-Result "`nGranting temporary admin access to $GlobalSPOAdminAddress for $($SiteURL.Url)" -IsError
        Set-SPOUser -Site $SiteURL.Url -LoginName $GlobalSPOAdminAddress -IsSiteCollectionAdmin:$true | Out-Null
        $SiteCollectionAdmins = Get-SPOUser -Site $SiteURL.Url | Where-Object { $_.IsSiteAdmin -and $_.LoginName -ne $GlobalSPOAdminAddress }
        Set-SPOUser -Site $SiteURL.Url -LoginName $GlobalSPOAdminAddress -IsSiteCollectionAdmin:$false | Out-Null
        # Write-Result "Temporary access granted and revoked for $GlobalSPOAdminAddress"
    }

    $SiteOwnerResults += [PSCustomObject]@{
        DisplayName             = $SiteURL.Title
        PrimaryOwnerEmail       = $SiteURL.Owner
        OtherAdminsDisplayName  = $SiteCollectionAdmins.DisplayName -join ","
        OtherAdminsEmail        = $SiteCollectionAdmins.LoginName -join ","
        IsGroup                 = $SiteCollectionAdmins.IsGroup -join ","
        SiteURL                 = $SiteURL.Url
    }

    If(($ProgressCount % 20) -eq 0 -or $ProgressCount -eq $AllSPOSites.count ){
        Write-Result "A totak if $($ProgressCount) out of $($AllSPOSites.count) has been processed"
    }
}

$ExportFileName = ".\SiteCollectionAdministrator_Report_for_" + ($SiteAdminReportType ? $SiteAdminReportType : "All")
Write-Result "`nExporting report to $ExportFileName.csv..." -Color "Cyan"
$SiteOwnerResults | Export-Csv "$ExportFileName.csv" -NoTypeInformation -UseCulture
Write-Result "Report generation complete." -Color "Green"