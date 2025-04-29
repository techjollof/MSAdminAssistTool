# Retrieving all mailbox types LastLogin, license count, admin role count

    This project practically get user last Sign-in information for office 365 objects Enables you generate a csv file the last usage for the all the object in the environment

You can also check for specific type of objects,

DiscoveryMailbox, EquipmentMailbox, GroupMailbox, RoomMailbox, SchedulingMailbox, SharedMailbox, TeamMailbox and UserMailbox

## Report types for the parameter ReportTypeSelection 
AssignedLicenses, LastSignInDetail, AdminRoles, AllReportDetail (default)

# How to use

Run powershell make sure you install both msonline and exchangeonlinemanagement mode
    
    Current user (non admin)
        1. Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false `
        2.Install-Module -Name MSonline, ExchangeonlineManagement -Scope CurrentUser -Force -AllowClobber -Confirm:$false 

    As administrator ( run powershell as admin)
        1. Set-ExecutionPolicy RemoteSigned -Confirm:$false `
        2. Install-Module -Name MSonline, ExchangeonlineManagement -Force -AllowClobber -Confirm:$false `

### Example 1 : Only one mailbox type
    .\GetUserLicenseInformationLastLogin.ps1 -RecipientTypes UserMailbox

### Example 1 : More than one mailbox type
    .\GetUserLicenseInformationLastLogin.ps1 -RecipientTypes UserMailbox, SharedMailbox

### Example 1 : Getting multiple mailbox types different report type
    .\GetUserLicenseInformationLastLogin.ps1 -RecipientTypes RoomMailbox, UserMailbox,SharedMailbox -ReportTypeSelection LastSignInDetail

### Report Destination folder, 

#### if ReportDestinationFolderPath not specified the current working directory where script is located will be used
    .\GetUserLicenseInformationLastLogin.ps1 -RecipientTypes RoomMailbox, UserMailbox,SharedMailbox -ReportTypeSelection LastSignInDetail -ReportDestinationFolderPath "Enter Your Preferre Path"


### Test Results for room mailbox
    .\GetUserLicenseInformationLastLogin.ps1 -RecipientTypes RoomMailbox
    
![Sample1](/Sample.png)

![Sample2](/sample2.png)
