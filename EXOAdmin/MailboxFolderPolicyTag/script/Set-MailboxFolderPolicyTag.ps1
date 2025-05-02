<#

    .SYNOPSIS
    This script stamps folders in mailboxes with retention or archival policy tags.

    .DESCRIPTION
    This script leverages EWS (Exchange Web Services) with OAuth authentication to stamp folders in either the primary or archive mailbox with a personal retention and archival policy tag.

    .PARAMETER TargetFolderName
    The name of the folder to be stamped with the retention policy tag.

    .PARAMETER ArchiveOrRetentionTagRawRetentionId
    The RawRetentionId of the retention or archive tag to be applied. You can retrieve this information by running the `Get-RetentionPolicyTag` cmdlet.

    .PARAMETER RetentionFlagsValue
    An integer value representing the retention flags, which can be retrieved using the MFCMAPI tool. Detailed steps for obtaining this value are provided in the README.md file.

    .PARAMETER ArchiveOrRetentionPeriodInDays
    The retention or archival period in days. This value can be obtained from the `AgeLimitForRetention` property when running `Get-RetentionPolicyTag`.

    .PARAMETER TenantInitialDomain
    The initial domain name used when the Microsoft tenant was created (e.g., "tenantname.onmicrosoft.com").

    .PARAMETER AzureEWSApplicationClientId
    The Application/Client ID of the Azure AD application with EWS delegation permissions.

    .PARAMETER TargetUserAccountsCsv
    The path to a CSV file containing a list of user accounts that the policy tag will be applied to.

    .PARAMETER TargetFolderLocation
    Specifies the location of the target folder. It can be set to either "PrimaryMailbox" or "ArchiveMailbox". The default value is "PrimaryMailbox".

    .PARAMETER ArchiveOrRetainAction
    Specifies the action that will be initiated: either "ArchiveAction" or "RetentionAction". The default value is "ArchiveAction".

    .EXAMPLE
        # Open and update the values in the "EWSRConfig.psd1" file
        .\Set-MailboxFolderPolicyTag.ps1 -UserPredefinedConfigData

    .EXAMPLE
        # Directly specify parameters (not recommended to skip the config file)
        .\Set-MailboxFolderPolicyTag.ps1 -TargetFolderName "FolderName" -ArchiveOrRetentionTagRawRetentionId XXXXXXXXXXXXXXXXXXXXX -RetentionFlagsValue 837 -ArchiveOrRetentionPeriodInDays 0 -TenantInitialDomain "tenantname.onmicrosoft.com" -AzureEWSApplicationClientId XXXXXXXXXXXXXXXXXXXXXXXXXX -TargetUserAccountsCsv .\UserAccounts.txt 

#>


[CmdletBinding(DefaultParameterSetName = "Manual")]
param (
    
    # Manual input parameters
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [string]$TargetFolderName,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [guid]$ArchiveOrRetentionTagRawRetentionId,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [int]$RetentionFlagsValue,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [int]$ArchiveOrRetentionPeriodInDays,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [ValidateScript({ (Resolve-DnsName $_) -and ($_ -like "*.onmicrosoft.com") })]
    $TenantInitialDomain,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [guid]$AzureEWSApplicationClientId,
    
    [Parameter(Mandatory, ParameterSetName = "Manual")]
    [System.IO.FileInfo]$TargetUserAccountsCsv,
    
    [Parameter(ParameterSetName = "Manual")]
    [ValidateSet("PrimaryMailBox", "ArchiveMailBox")]
    $TargetFolderLocation = "PrimaryMailBox",
    
    [Parameter(ParameterSetName = "Manual")]
    [ValidateSet("ArchiveAction", "RetentionAction")]
    $ArchiveOrRetainAction = "ArchiveAction",
    
    
    # Switch for loading values from a config file
    [Parameter(Mandatory, ParameterSetName = "Predefined")]
    [switch]$UserPredefinedConfigData
)
    

function Write-Log {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [string]$LogFile = "$PSScriptRoot\logs.txt"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] - $Message"

    try {
        Add-Content -Path $LogFile -Value $logEntry
    }
    catch {
        Write-Host "Failed to write log to $LogFile. Error: $_" -ForegroundColor Red
    }
}


function Read-Parameters {
    param (
        [string]$FilePath
    )

    if (Test-Path $FilePath) {
        return Import-PowerShellDataFile -Path $FilePath
    } else {
        throw "Configuration file not found: $FilePath"
    }
}

function Read-Config {
    param (
        [string]$ConfigFilePath
    )

    try {
        # Ensure the file exists
        if (-not (Test-Path $ConfigFilePath)) {
            throw "Config file not found at: $ConfigFilePath"
        }

        # Read the config
        $Config = Read-Host -Path $ConfigFilePath | ConvertFrom-Json
        return $Config
    }
    catch {
        Write-Log "Error reading config file: $_"  Error
        throw
    }
}

function Validate-ConfigValues {
    param (
        [hashtable]$Values
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        if ($null -eq $value) {
            Write-Log "$key is null. Terminating script." "Error"
            throw "$key in config is required but was null."
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            Write-Log "$key is empty or whitespace. Terminating script." "Error"
            throw "$key in config is required but was empty or whitespace."
        }

        if ($value -is [Guid] -and $value -eq [Guid]::Empty) {
            Write-Log "$key is an empty GUID. Terminating script." "Error"
            throw "$key in config is required but was an empty GUID."
        }
    }
}



function Set-FolderFPolicyTag {
    param (
        [Parameter(Mandatory)]
        [string]$MailboxName,

        [Parameter(Mandatory)]
        [string]$TargetFolderName,

        [Parameter(Mandatory)]
        [ValidateSet("PrimaryMailBox", "ArchiveMailBox")]
        [string]$TargetFolderLocation,

        [Parameter(Mandatory)]
        [ValidateSet("ArchiveAction", "RetentionAction")]
        [string]$ArchiveOrRetainAction,

        [Parameter(Mandatory)]
        [guid]$ArchiveOrRetentionTagRawRetentionId,

        [Parameter(Mandatory)]
        [int]$RetentionFlagsValue,

        [Parameter(Mandatory)]
        [int]$ArchiveOrRetentionPeriodInDays,

        [Parameter(Mandatory)]
        [object]$Service  # EWS Managed API ExchangeService object

    )

    Write-Log "Stamping Policy on folder for Mailbox Name: $MailboxName"

    # Change the user to Impersonate
    $service.ImpersonatedUserId = new-object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $MailboxName)

    # Search for the folder you want to stamp the property on
    $oFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1)
    $oSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName, $TargetFolderName)

    if ($TargetFolderLocation -eq "ArchiveMailBox") {
        # If the folder is in the archive mailbox
        $oFindFolderResults = $service.FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::ArchiveMsgFolderRoot, $oSearchFilter, $oFolderView)
    }
    else { 
        # If the folder is in the regular mailbox
        $oFindFolderResults = $service.FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot, $oSearchFilter, $oFolderView)
    }

    # Checking if the folder has been found
    if ($oFindFolderResults.TotalCount -eq 0) {
        Write-Log "Folder does not exist in Mailbox: $MailboxName"
    }
    else {
        Write-Log "Folder found in Mailbox: $MailboxName"

        if ($ArchiveOrRetainAction -eq "RetentionAction") {
            # PR_POLICY_TAG 0x3019
            $PolicyTag = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3019, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary)
            # PR_RETENTION_FLAGS 0x301D    
            $RetentionFlags = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301D, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
            # PR_RETENTION_PERIOD 0x301A
            $PolicyPeriod = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301A, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
        }
        else {
            if ($TargetFolderLocation -eq "ArchiveMailBox") {
                Write-Log "Archive tag cannot be applied to a folder in the online archive folder, only retention tags can be applied to folders in online archive folder"
                break
            }
            else {
                # PR_ARCHIVE_TAG 0x3018 – We use the PR_ARCHIVE_TAG
                $PolicyTag = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3018, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary)
                # PR_RETENTION_FLAGS 0x301D
                $RetentionFlags = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301D, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
                # PR_ARCHIVE_PERIOD 0x301E - We use the PR_ARCHIVE_PERIOD
                $PolicyPeriod = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301E, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
            }
        }

        # Change the GUID based on your policy tag
        $PolicyTagRetentionId = new-Object Guid("{$ArchiveOrRetentionTagRawRetentionId}")
        # Bind to the folder found
        $oFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, $oFindFolderResults.Folders[0].Id)

        # Same as that on the policy - 16 specifies that this is an ExplicitArchiveTag
        $oFolder.SetExtendedProperty($RetentionFlags, $RetentionFlagsValue)
        # Same as that on the policy - Since this tag is disabled the Period would be 0
        $oFolder.SetExtendedProperty($PolicyPeriod, $ArchiveOrRetentionPeriodInDays)
        # Same as that on the policy - Since this tag is disabled the Period would be 0
        $oFolder.SetExtendedProperty($PolicyTag, $PolicyTagRetentionId.ToByteArray())

        # Update the folder information
        $oFolder.Update()

        Write-Log "Retention policy stamped on folder: $MailboxName"
    }

    # Reset Impersonation
    $service.ImpersonatedUserId = $null
}



# Only run this block if Predefined is explicitly used
if ($PSCmdlet.ParameterSetName -eq 'Predefined') {
    # Read config
    $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "EWSConfig.psd1"
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "EWS config file not found: $ConfigPath" "Error"
        throw "Config file is required for predefined parameter set."
    }

    try {
        $RetrieveValue = Import-PowerShellDataFile -Path $ConfigPath
    }
    catch {
        Write-Log "Failed to import config file. Error: $_" "Error"
        throw
    }

    # Extract and convert
    $TargetFolderName                    = $RetrieveValue.TargetFolderName
    $ArchiveOrRetentionTagRawRetentionId = [guid]$RetrieveValue.ArchiveOrRetentionTagRawRetentionId
    $RetentionFlagsValue                = [int]$RetrieveValue.RetentionFlagsValue
    $ArchiveOrRetentionPeriodInDays     = [int]$RetrieveValue.ArchiveOrRetentionPeriodInDays
    $TenantInitialDomain                = $RetrieveValue.TenantInitialDomain
    $AzureEWSApplicationClientId        = [guid]$RetrieveValue.AzureEWSApplicationClientId
    $TargetFolderLocation               = $RetrieveValue.TargetFolderLocation
    $ArchiveOrRetainAction              = $RetrieveValue.ArchiveOrRetainAction

    # Resolve full path for CSV
    $TargetUserAccountsCsvPath = Join-Path -Path $PSScriptRoot -ChildPath $RetrieveValue.TargetUserAccountsCsv
    if (-not (Test-Path $TargetUserAccountsCsvPath)) {
        Write-Log "Target user accounts CSV not found: $TargetUserAccountsCsvPath" "Error"
        throw
    }

    # Validate
    $ConfigValues = @{
        TargetFolderName                     = $TargetFolderName
        ArchiveOrRetentionTagRawRetentionId  = $ArchiveOrRetentionTagRawRetentionId
        RetentionFlagsValue                  = $RetentionFlagsValue
        ArchiveOrRetentionPeriodInDays       = $ArchiveOrRetentionPeriodInDays
        TenantInitialDomain                  = $TenantInitialDomain
        AzureEWSApplicationClientId          = $AzureEWSApplicationClientId
        TargetFolderLocation                 = $TargetFolderLocation
        ArchiveOrRetainAction                = $ArchiveOrRetainAction
        TargetUserAccountsCsv                = $TargetUserAccountsCsvPath
    }

    Validate-ConfigValues -Values $ConfigValues
    Write-Log "Configuration successfully loaded from predefined config."
}
else {
    Write-Log "Using manual parameters. Skipping predefined config."
}



# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false

# Import Microsoft.Exchange.WebServices Module
if ("Microsoft.Exchange.WebServices" -in (Get-Module).Name) {
    Write-Log "The EWS Module is already installed and imported"
}
else {
    Import-Module -Name ".\EWSManagedAPI\Microsoft.Exchange.WebServices.dll" -ErrorAction SilentlyContinue -ErrorVariable ModuleImport

    if ($ModuleImport.Count -eq 0) {
        Write-Log "Microsoft Exchange WebServices Module imported successfully" Info
    }
    else {
        Write-Log "The Microsoft Exchange WebServices module failed to import. Ensure 'Microsoft.Exchange.WebServices.dll' exists in the 'EWSManagedAPI' folder."  Error
        break
    }
}

# Import MSAL.PS Module for Microsoft Graph Authentication
if ($null -eq (Get-InstalledModule MSAL.PS -ErrorAction SilentlyContinue)) {
    Install-Module MSAL.PS -Confirm:$false -Scope CurrentUser
    Import-Module MSAL.PS -ErrorAction SilentlyContinue -ErrorVariable ModuleImport
}
else {
    Import-Module MSAL.PS -ErrorAction SilentlyContinue -ErrorVariable ModuleImport
}

# Check if MSAL.PS was imported correctly
if ($ModuleImport.Count -eq 0) {
    Write-Log "Microsoft Graph Authentication (MSAL.PS) Module imported successfully" Info
}
else {
    Write-Log "The MSAL.PS module failed to import. Please restart PowerShell and ensure the module is installed properly." Error
    break
}



# Creating EWS interface
$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_SP1)

# Provide your Office 365 Tenant Id or Tenant Domain Name
# Provide Azure AD Application (client) Id of your app.
# You should have configured the Delegated permission "EWS.AccessAsUser.All" in the app.
$MsalParams = @{
    ClientId = $AzureEWSApplicationClientId
    TenantId = $TenantInitialDomain   
    Scopes   = "https://outlook.office.com/EWS.AccessAsUser.All"  
}

$MsalResponse = Get-MsalToken @MsalParams
$EWSAccessToken = $MsalResponse.AccessToken

# Set the Credentials
$service.Credentials = [Microsoft.Exchange.WebServices.Data.OAuthCredentials]$EWSAccessToken

# Change the URL to point to your cas server
$service.Url = new-object Uri("https://outlook.office365.com/EWS/Exchange.asmx");

# Set $UseAutoDiscover to $true if you want to use AutoDiscover else it will use the URL set above
$UseAutoDiscover = $false

#Read data from the UserAccounts.txt.
#This file must exist in the same location as the script.

import-csv $TargetUserAccountsCsv | foreach-object {
    $WindowsEmailAddress = $_.EmailAddress.Trim()

    if ($UseAutoDiscover -eq $true) {
        Write-log "Autodiscovering.." Info
        $UseAutoDiscover = $false
        $service.AutodiscoverUrl($WindowsEmailAddress)
        Write-log "Autodiscovering Done! EWS URL set to $service.Url" Info

    }
    #To catch the Exceptions generated
    trap [System.Exception] {
        Write-log "$($_.Exception.Message)" Error
        con
        tinue;
    }
    
    Set-FolderFPolicyTag `
    -MailboxName $WindowsEmailAddress `
    -TargetFolderName $TargetFolderName `
    -TargetFolderLocation $TargetFolderLocation `
    -ArchiveOrRetainAction $ArchiveOrRetainAction `
    -ArchiveOrRetentionTagRawRetentionId $ArchiveOrRetentionTagRawRetentionId `
    -RetentionFlagsValue $RetentionFlagsValue `
    -ArchiveOrRetentionPeriodInDays $ArchiveOrRetentionPeriodInDays `
    -Service $service

}