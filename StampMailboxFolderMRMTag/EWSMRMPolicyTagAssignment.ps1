
# The script requires the EWS managed API, which can be downloaded here:
# https://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=c3342fb3-fbcc-4127-becf-872c746840e1
# This also requires PowerShell 6.0
# Make sure the Import-Module command below matches the DLL location of the API.
# This path must match the install location of the EWS managed API. Change it if needed.

<#

    
    .SYNOPSIS
    This program used for stamping folder in mailbox with tag

    .DESCRIPTION
    This program lerages EWS aith OAuth to stamp a folder in primary mailbox or archive mailbox with personal retention and archival policy tag.
    
    .PARAMETER TargetFolderName, 
    This is is the name of the fo the folder to be stamped with the retention policy tag.

	.PARAMETER ArchiveOrRetentionTagRawRetentionId, 
    This is the RetentionId/RawRetentionId of the retention/arctive tag to able appliced. You retrive information by running the following get-RetentionPolicyTag

	.PARAMETER RetentionFlagsValue,
    This is an integer and the value can be retrived by using MFCMAPI program. The steps are provided in the README.md file. 


	.PARAMETER ArchiveOrRetentionPeriodInDays, 
    The is teh archival or retention peroid duration, it can be retrieve by AgeLimitForRetention property of get-RetentionPolicyTag 

	.PARAMETER TenantInitialDomain, 
    The target tenant initial domain that was used when the Microsoft Tenant was created.

	.PARAMETER AzureEWSApplicationClientId, 
    The is the application/client ID of the Azure AD application with EWS delegation permission


	.PARAMETER TargetUserAccountsCsv, 
    This is the point to the path where the list of users are contain on which the tag will be implemented

	.PARAMETER TargetFolderLocation = "PrimaryMailBox", 
    This specifies the location teh target folder that was specified by TargetFolderName parameter. It takes two values PrimaryMailBox and ArchivMailBox. The default value is PrimaryMailBox.


	.PARAMETER ArchiveOrRetainAction = "ArchiveAction"
    This specifies tha action that will initiated whether archive action of retention action. It takes "ArchiveAction","RetentionAction" and the default is ArchiveAction.



    .EXAMPLE
        Open and update the values of the "EWSRequiredParameters.txt"
        .\EWSMRMProgram.ps1
        

    .EXAMPLE
        If you do not want to use the txt ( not recommended)
        .\EWSMRMPolicyTagAssignment.ps1 -TargetFolderName "FolderName" -ArchiveOrRetentionTagRawRetentionId XXXXXXXXXXXXXXXXXXXXX -RetentionFlagsValue 837 -ArchiveOrRetentionPeriodInDays 0 -TenantInitialDomain TENANTNAME.onmicrosoft.com -AzureEWSApplicationClientId XXXXXXXXXXXXXXXXXXXXXXXXXX -TargetUserAccountsCsv .\UserAccounts.txt 

    #> 


[CmdletBinding()]
param (
    #Change the name of the folder. This is the folder the properties will be stamped on.
    [Parameter(Mandatory)]
    [string]
    $TargetFolderName,

    # Theis is the RetentionId/RawRetentionId of the retention/arctive tag to able appliced. You retrive information by running the following get-RetentionPolicyTag
    [Parameter(Mandatory)]
    [guid]
    $ArchiveOrRetentionTagRawRetentionId,

    # RetentionFlagsValue from MFAC MAPI
    [Parameter(Mandatory)]
    [int]
    $RetentionFlagsValue,

    # ArchiveOrRetentionPeriod in days from MFCMAPI, the can be specified for the both retention and archiving
    [Parameter(Mandatory)]
    [int]
    $ArchiveOrRetentionPeriodInDays,

    # for tenant initial domain with onmicrosoft.com
    [Parameter(Mandatory)]
    [ValidateScript({(Resolve-DnsName $_) -and ($_ -like "*.onmicrosoft.com")})]
    $TenantInitialDomain,

    # App id
    [Parameter(Mandatory)]
    [guid]
    $AzureEWSApplicationClientId,

    # file path name where in the location when its located
    [Parameter(Mandatory)]
    [System.IO.FileInfo]
    $TargetUserAccountsCsv,

    # Where is the folder located, archive or primary mailbox default is primary mailbox "PrimaryMailBox"
    [Parameter()]
    [ValidateSet("PrimaryMailBox","ArchiveMailBox")]
    $TargetFolderLocation = "PrimaryMailBox",

    # Policy Type Archive or Retention
    [Parameter()]
    [ValidateSet("ArchiveAction","RetentionAction")]
    $ArchiveOrRetainAction = "ArchiveAction"

)

function prompt {
    $p = Split-Path -leaf -path (Get-Location)
    "$p> "
}
prompt

# Parameter help description
[string]$info = "White"                # Color for informational messages
[string]$warning = "Yellow"            # Color for warning messages
[string]$error = "Red"                 # Color for error messages
[string]$LogFile = ".\Log.txt"         # Path of the Log Filefunction 

Clear-Content -Path $LogFile
function StampPolicyOnFolder($MailboxName)
{
    Write-host "`nStamping Policy on folder for Mailbox Name:" $MailboxName -foregroundcolor $info
    Add-Content $LogFile ("`nStamping Policy on folder for Mailbox Name:" + $MailboxName)

    #Change the user to Impersonate
    $service.ImpersonatedUserId = new-object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress,$MailboxName);

    #Search for the folder you want to stamp the property on
    $oFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1)
    $oSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName,$TargetFolderName)

    if($TargetFolderLocation -eq "ArchiveMailBox"){
        #if the folder is in the in archivemailbox
        $oFindFolderResults = $service.FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::ArchiveMsgFolderRoot,$oSearchFilter,$oFolderView)
    }else { 
        #if the folder is in the regular mailbox
        $oFindFolderResults = $service.FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot,$oSearchFilter,$oFolderView)
    }

    # checking if folder has been found
    if ($oFindFolderResults.TotalCount -eq 0)
    {
        Write-host "Folder does not exist in Mailbox:" $MailboxName -foregroundcolor $warning
        Add-Content $LogFile ("Folder does not exist in Mailbox:" + $MailboxName)
    }
    else
    {
        Write-host "Folder found in Mailbox:" $MailboxName -foregroundcolor $info

        if ($ArchiveOrRetainAction -eq "RetentionAction") {
            #PR_POLICY_TAG 0x3019
            $PolicyTag = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3019,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary);        
            #PR_RETENTION_FLAGS 0x301D    
            $RetentionFlags = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301D,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer);
            #PR_RETENTION_PERIOD 0x301A
            $PolicyPeriod = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301A,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer);        
        }else {
            if ($TargetFolderLocation -eq "ArchiveMailBox") {
                Write-Host "`n`nArchive tag cannot be applied to a folder in the online archive folder, only rentention tags can be applied to folders in online archive folder`n`n" -ForegroundColor Red
                Add-Content $LogFile ("Archive tag cannot be applied to a folder in the online archive folder, only rentention tags can be applied to folders in online archive folder")
                break
            }else{
                #PR_ARCHIVE_TAG 0x3018 – We use the PR_ARCHIVE_TAG
                $PolicyTag = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x3018,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary);
                #PR_RETENTION_FLAGS 0x301D
                $RetentionFlags = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301D,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer);
                #PR_ARCHIVE_PERIOD 0x301E - We use the PR_ARCHIVE_PERIOD
                $PolicyPeriod = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x301E,[Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer);
            }
        }


        #Change the GUID based on your policy tag
        $PolicyTagRetentionId = new-Object Guid("{$ArchiveOrRetentionTagRawRetentionId}");

        #Bind to the folder found
        $oFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$oFindFolderResults.Folders[0].Id)

        #Same as that on the policy - 16 specifies that this is a ExplictArchiveTag
        $oFolder.SetExtendedProperty($RetentionFlags, $RetentionFlagsValue)

        #Same as that on the policy - Since this tag is disabled the Period would be 0
        $oFolder.SetExtendedProperty($PolicyPeriod, $ArchiveOrRetentionPeriodInDays)

        #Same as that on the policy - Since this tag is disabled the Period would be 0
        $oFolder.SetExtendedProperty($PolicyTag, $PolicyTagRetentionId.ToByteArray())

        #Update the folder information
        $oFolder.Update()

        Write-host "Retention policy stamped!" -foregroundcolor $info
        Add-Content $LogFile ("Retention policy stamped!")
    }

    $service.ImpersonatedUserId = $null

}

# Check the list of imported modules and check if module is installed
#Import EWS Module
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false
if("Microsoft.Exchange.WebServices" -in (Get-Module).Name){
    Write-Host "`nThe EWS Mudule is already installed and imported"
}else {
    Import-Module -Name ".\EWSManagedAPI\Microsoft.Exchange.WebServices.dll" -ErrorAction SilentlyContinue -ErrorVariable ModuleImport

    if ($ModuleImport.Count -eq 0) {
        Write-Host "`nMicrosoft Exchange WebServices Module imported successfully `n"
    }else {
        Write-Host "`nThe Microsoft Exchange WebServices module failed to import. Either the EWS module doe exist in the specified folder.`nPlease check and make sure 'Microsoft.Exchange.WebServices1.dll' is located in folder EWSManagedAPI !!!"
        break
    }
}
#Import MSAL.PS Module for graph authentication
if ($null -eq (Get-InstalledModule MSAL.PS -ErrorAction SilentlyContinue)) {
    Install-Module MSAL.PS -Confirm:$false -Scope CurrentUser
    Import-Module MSAL.PS
}else {
    Import-Module MSAL.PS -ErrorAction SilentlyContinue -ErrorVariable ModuleImport

    if ($ModuleImport.Count -eq 0) {
        Write-Host "`nMicrosoft Graph Authentication Module imported successfully"
    }else {
        Write-Host "`nThe MSAL.PS module failed to import. Please close the powershell and reopen if the module is already installed!!!"
        break
    }
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
$EWSAccessToken  = $MsalResponse.AccessToken

# Set the Credentials
$service.Credentials = [Microsoft.Exchange.WebServices.Data.OAuthCredentials]$EWSAccessToken

# Change the URL to point to your cas server
$service.Url = new-object Uri("https://outlook.office365.com/EWS/Exchange.asmx");

# Set $UseAutoDiscover to $true if you want to use AutoDiscover else it will use the URL set above
$UseAutoDiscover = $false

#Read data from the UserAccounts.txt.
#This file must exist in the same location as the script.

import-csv $TargetUserAccountsCsv | foreach-object {
    $WindowsEmailAddress = $_.WindowsEmailAddress.ToString()

    if ($UseAutoDiscover -eq $true) {
        Write-host "Autodiscovering.." -foregroundcolor $info
        $UseAutoDiscover = $false
        $service.AutodiscoverUrl($WindowsEmailAddress)
        Write-host "Autodiscovering Done!" -foregroundcolor $info
        Write-host "EWS URL set to :" $service.Url -foregroundcolor $info

    }
    #To catch the Exceptions generated
    trap [System.Exception] 
    {
        Write-host ("Error: " + $_.Exception.Message) -foregroundcolor $error;
        Add-Content $LogFile ("Error: " + $_.Exception.Message);
        continue;
    }
    StampPolicyOnFolder($WindowsEmailAddress)
}