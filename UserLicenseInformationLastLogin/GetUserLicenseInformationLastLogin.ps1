# Get all only user specified in the 
[CmdletBinding()]
param (
    [Parameter(HelpMessage = "choose any of the following type of mailbox or multiple seperated by comma`nEquipmentMailbox, GroupMailbox, LegacyMailbox, RoomMailbox, SchedulingMailbox, SharedMailbox, TeamMailbox,UserMailbox")]
    [string[]] 
    $RecipientTypes,

    [Parameter()]
    [switch]
    $AllRecipientTypes,

    # Repoort to be generate
    [Parameter()]
    [ValidateSet("AssignedLicenses","LastSignInDetail","AdminRoles","AllReportDetail")]
    $ReportTypeSelection = 'AllReportDetail',

    [Parameter()]
    [string]
    $ReportDestinationFolderPath = '.'
)


#checking connection status for msol and exchangeonline
if ($null -eq (Get-Command Get-OrganizationConfig -errorAction SilentlyContinue)) {

    if ($null -ne (Get-Command Connect-ExchangeOnline -errorAction SilentlyContinue)) {
        Write-Host "Now attempting to connect exchangeonline..........."
        Connect-ExchangeOnline  -ShowBanner:$false
        Write-Host "..... exchangeonline connected successfully"
    }else {
        Write-Host "Exchangeonline no installed run the following command install and connect"
        Write-Host "`t1.`tSet-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false `
        2.`tInstall-Module -Name ExchangeonlineManagement -Scope CurrentUser -Force -AllowClobber -Confirm:$false `
        3.`tConnect-ExchangeOnline" -ForegroundColor Yellow
    }
}else{
    Write-Host "Exchange service management is already connected"
}

#msol connection info

#checking connection status for msol and exchangeonline
if ($null -eq (Get-MsolCompanyInformation -errorAction SilentlyContinue)) {
    if ($null -ne (Get-Command Connect-MsolService -errorAction SilentlyContinue)) {
        Write-Host "Now attempting to connect MSonline..........."
        Connect-MsolService 
        Write-Host "..... MSonline connected successfully"
    }else {
        Write-Host "Microsoft Online not installed run the following command install and connect"
        Write-Host "`t1.`tSet-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false `
        2.`tInstall-Module -Name MSonline -Scope CurrentUser -Force -AllowClobber -Confirm:$false `
        .`tConnect-MsolService" -ForegroundColor Yellow
    }
}else{
    Write-Host "MSonline service management is already connected"
}


#getting all object information
$Results = @()
$LicenseDetailFile = ".\LicenseFriendlyNames.csv"

#get object depending on the the select type
Write-Host "`n`tGetting all the selected mailbox information" -ForegroundColor Yellow
if(-not($RecipientTypes) -and -not($AllRecipientTypes.IsPresent)) {
    $mbx = Get-Mailbox -ResultSize Unlimited | Where-Object {$_.RecipientTypeDetails -ne "DiscoveryMailbox"}
}elseif($AllRecipientTypes){
    $mbx = Get-Mailbox -ResultSize Unlimited | Where-Object {$_.RecipientTypeDetails -ne "DiscoveryMailbox"}
}else{
    $RecipientTypes = $RecipientTypes -join ','
    $mbx = Get-Mailbox -RecipientTypeDetails $RecipientTypes.Split(',') -ResultSize Unlimited | Where-Object {$_.RecipientTypeDetails -ne "DiscoveryMailbox"}
}

#geting licese frindly names
Write-Host "`n`tGetting all the Microsoft License name and identities information" -ForegroundColor Yellow
$LicenseDetailFile = ".\LicenseFriendlyNames.csv"
try {
    Invoke-RestMethod -Uri  "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv" -OutFile ".\LicenseFriendlyNames.csv"
}Catch {
    $errorMessage = $_.ErrorDetails.Message -replace "`n|`r"
}finally {
    if (Test-Path $LicenseDetailFile){
        if($null -ne (Get-content $LicenseDetailFile)){
            Write-Host "`n`tgetting the csv file content " -ForegroundColor Yellow
            $getlicenseName = Import-csv $LicenseDetailFile
            $getlicenseNameUnique = $getlicenseName | Sort-Object String_Id -Unique
        }else {
            Write-Host "The license file exist and but content is empty"
        }
    }else{
        Write-Host "`n The file path does not exist or empty or URL error `n"
        Write-Host $errorMessage -ForegroundColor Red
    }
}


Write-Host "`n`tGetting all the selected object properties information" -ForegroundColor Yellow
$itemCount = 0
$mbx | ForEach-Object {
    #assign object
    $UserObject = $_ 
    $itemCount += 1
    Write-Progress -Activity "Retrieving object properties from the server $itemCount of $($mbx.count)" -Status " Currently Processing: $($UserObject.DisplayName)" -PercentComplete ((($itemCount) / $mbx.count) * 100)

    #getting login information for the each
    $mbxStat = Get-MailboxStatistics  -Identity $UserObject.UserPrincipalName

    if($null -eq $mbxStat.LastUserActionTime){
        $LastActionTime = "Never Logged in"
        $InactiveDaysOfUser = ''
    }else{
        $LastActionTime = $mbxStat.LastUserActionTime
        $InactiveDaysOfUser = ((Get-Date) - $mbxStat.LastUserActionTime).Days
    }

    #getting license information
    $UserBasicInfo = Get-MsolUser -UserPrincipalName $UserObject.UserPrincipalName
    $UserLicensesID = $UserBasicInfo.Licenses.AccountSkuId

    if ($UserLicensesID.count -eq 0) {
        $AssignLicenseName = "No Assigned License"
    }else{
        $AssignedLicenses = $UserLicensesID  | ForEach-Object {$_ -Split ":" | Select-Object -Last 1}
        $AssignLicenseName = ($AssignedLicenses | ForEach-Object{ $lid = $_; $getlicenseNameUnique.where({$_.String_Id -eq $lid}).Product_Display_Name} | Sort-Object -Unique) -join ','
    }
    
    #getting roles
    $UserRoles=(Get-MsolUserRole -UserPrincipalName $UserObject.UserPrincipalName).Name
    if ($UserRoles.count -eq 0) {
        $AssignedRoles = "No Roles"
        $RoleCount = $UserRoles.count
    }else{
        $AssignedRoles = $UserRoles -join ','
        $RoleCount = $UserRoles.count
    }

    # appending the results
    $Results += [PSCustomObject]@{
        'UserPrincipalName'         =   $UserObject.UserPrincipalName
        'DisplayName'               =   $UserObject.DisplayName
        'LastLogonTime'             =   $LastActionTime
        'CreationTime'              =   $UserObject.WhenCreated
        'MailboxCreatiionTime'      =   $UserObject.WhenMailboxCreated
        'ModifiedObjectTime'        =   $UserObject.WhenChanged
        'InactiveDays'              =   $InactiveDaysOfUser
        'MailboxType'               =   $UserObject.RecipientTypeDetails
        'AssignedLicenses'          =   $AssignLicenseName
        'LicenseCount'              =   $UserLicensesID.count  
        'AssignedRoles'             =   $AssignedRoles
        'RoleCount'                 =   $RoleCount
        'LastPasswordChange'        =   $UserBasicInfo.LastPasswordChangeTimestamp
    }
}

#exporting content to specified path or current location if not specified
if ((Test-Path $ReportDestinationFolderPath) -eq $false) {
    $ReportDestinationFolderPath = '.'
}

$ExportDate = Get-Date -Format "MM-dd-yyyy HH-mm"
Write-Host "Content will be saved to the current scirpt location or the specified"

if ($ReportTypeSelection -eq 'AssignedLicenses') {
    $Results | Select-Object DisplayName, UserPrincipalName, AssignedLicenses, LicenseCount | Export-Csv $ReportDestinationFolderPath'\UsersAssignedLicenses'$ExportDate'.csv'   
}elseif ($ReportTypeSelection -eq 'LastSignInDetail') {
    $Results | Select-Object DisplayName, UserPrincipalName, LastLogonTime, CreationTime, MailboxCreatiionTime, ModifiedObjectTime, LastPasswordChange | Export-Csv $ReportDestinationFolderPath'\UserLastSignInDetail'$ExportDate'.csv'
}elseif ($ReportTypeSelection -eq 'AdminRoles') {
    $Results | Select-Object DisplayName, UserPrincipalName, AssignedRoles, RoleCount| Export-Csv $ReportDestinationFolderPath'\UsersAssignedLicenses'$ExportDate'.csv'   
}else{
    $Results | Export-Csv $ReportDestinationFolderPath'\UserLicenseInformationLastLogin'$ExportDate'.csv'
}
