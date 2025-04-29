
# make users have been assigned PhoneSytem license
# have a csv file with the following colunms EmailAddress, PhoneNumber
# Written by Narh Daniel Tetteh, if you have any error, reach out to me on techjollof@gmail.com
# NO WARRENT GARR

# 
# SAMPLE – AS IS, NO WARRANTY This script assumes a connection to (to get source values) and the target on-premises Active Directory Domain Services (to stamp the ADUser object).


<#
.SYNOPSIS
	Assingning number in bulk or single user
.DESCRIPTION
	Assingning number in bulk or single user and results can be exported to csv file.
	Export can seperate file for both failed and succeeded or all togther in a single file
.PARAMETER BulkAssignment
	this is a switch parameter, if specified then the BulkAssignmentCsvData must be provided, if not present single user 
	action is performed
	The default value is FALSE
.PARAMETER PhoneNumberType
	The type of phone number to assign to the user or resource account. The supported values are DirectRouting, 
	CallingPlan, and OperatorConnect. When you acquire a phone number you will typically know which type it is.
	The default is none
.PARAMETER BulkAssignmentCsvData
	Path to CSV file for bulk number assignment. Mandatory if the BulkAssignment parameter is specified
.EXAMPLE 
	This will perform assignment for one user by first requesting the value for PhoneNumberType else it will failed
	PS >
	.\PhoneNumberAssignment.ps1
.EXAMPLE 
	This will perform assignment for one user
	PS >
	.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting
.EXAMPLE
	For bulk action specifing the source csv file directly
	PS>
	.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting -BulkAssignmentCsvData ".\NumebrAssignment.csv"
.EXAMPLE
	For bulk action using the BulkAssignment switch, this will proceed to request the BulkAssignmentCsvData path
	PS>
	.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting -BulkAssignment

.OUTPUTS
	Output from this cmdlet exports csv file which contains the results from your assign process
.LINK
	if you have an error in running the script, you refer to the following link
		https://social.technet.microsoft.com/wiki/contents/articles/38496.unblock-downloaded-powershell-scripts.aspx
	for more information
		https://learn.microsoft.com/en-us/powershell/module/teams/set-csphonenumberassignment?view=teams-ps
		https://learn.microsoft.com/en-us/microsoftteams/assign-change-or-remove-a-phone-number-for-a-user
#>

[CmdletBinding(DefaultParameterSetName = "None")]
param(
	[Parameter(ParameterSetName = "BulkAssignment", HelpMessage ="Specify and initiates bulk action")]
	[switch]
	$BulkAssignment,

	[Parameter()]
	[Parameter(Mandatory, ParameterSetName = "BulkAssignment", HelpMessage ="specify the file path for bulk user action csv")]
	$BulkAssignmentCsvData,

	[Parameter(Mandatory=$true)]
	[ValidateSet("DirectRouting", "CallingPlan", "OperatorConnect")]
	$PhoneNumberType
)

# regex for email validation
#$EmailValidationRegex = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$'

$CompletedAndFailedObjects = @()

function Set-UserPhoneNumber ($EmailAddress, $PhoneNumber) {

	$AssignmentResults = @()

	if(-not([string]::IsNullOrWhiteSpace($EmailAddress)) -and -not([string]::IsNullOrWhiteSpace($PhoneNumber))){
	# verify if Phone system is assigned and enble enterprise voice
		Set-CsPhoneNumberAssignment -Identity $EmailAddress -EnterpriseVoiceEnabled $true -EA SilentlyContinue -EV LicenseUserError
			
		if($LicenseUserError){
			$AssignmentResults += [PSCustomObject]@{
				EmailAddress	= 	$EmailAddress
				TeamType	    = 	$PhoneNumber
				AssignStatus	=	"Failed"
				FailureReason 	= 	$LicenseUserError[0].ErrorDetails.Message	
			}
		}else{
			# Assign number and if number success update table
			Set-CsPhoneNumberAssignment -Identity $EmailAddress -PhoneNumber $PhoneNumber -PhoneNumberType $PhoneNumberType -EA SilentlyContinue -EV NumberAsignError
			$AssignmentResults += [PSCustomObject]@{
				EmailAddress	= 	$EmailAddress
				TeamType	    = 	$PhoneNumber
				AssignStatus	=	if($NumberAsignError){"Failed"}else{"Succeeded"}
				FailureReason 	= 	if($NumberAsignError){$LicenseUserError[0].ErrorDetails.Message}else{"Succeeded"}	
			}
		}
		return $AssignmentResults
	}else {
		Write-Host " The email address or phone number provided is null " -ForegroundColor Red
	}
}

Write-Host "`n`n #############  Checking and Assigning numbers to users #############`n`n" -ForegroundColor Green

if($BulkAssignment.IsPresent -or $PSBoundParameters["BulkAssignmentCsvData"]){

	if([System.IO.File]::Exists($BulkAssignmentCsvData)){

		$UsersAcc = Import-Csv $BulkAssignmentCsvData

		$UsersAcc | ForEach-Object {
		
			$acc = $_
			$ActionResults = Set-UserPhoneNumber -EmailAddress $acc.EmailAddress -PhoneNumber $acc.PhoneNumber
			$CompletedAndFailedObjects += $ActionResults
			$cu = $CompletedAndFailedObjects[-1] 
			write-host ("{0}`t`t`t`t`t{1} " -f $cu.AssignStatus,$cu.EmailAddress) -ForegroundColor DarkMagenta
		}

		$ExportOption = ($((Write-Host ("`n`nExport both failed and succeeded objects to the same file [Yy] ? : ") -NoNewline -ForegroundColor Yellow) ;Read-Host))

		if ($ExportOption){
			$CompletedAndFailedObjects |  Where-Object{$_.AssignStatus -eq "Failed"} | Export-csv ".\PhoneNumberAssignment_Failed_Results_$((Get-Date).ToString('MM-dd-yyyy_hh-mm')).csv" -NoTypeInformation
			$CompletedAndFailedObjects |  Where-Object{$_.AssignStatus -eq "Succeeded"} | Export-csv ".\PhoneNumberAssignment_Succeeded_Results_$((Get-Date).ToString('MM-dd-yyyy_hh-mm')).csv" -NoTypeInformation
		}else{
			Write-Host " `n`n  Export all results in single file ..........."
			$CompletedAndFailedObjects | Export-csv ".\PhoneNumberAssignmentResults_$((Get-Date).ToString('MM-dd-yyyy_hh-mm')).csv" -NoTypeInformation
		}
	}else {
		Write-Host " The file path is invalid or does not exist $($BulkAssignmentCsvData) " -ForegroundColor Red
	}

}else {
	Write-Host "####  Signle user assignment has been selected, enter the requested information for the user #####`n" -ForegroundColor Green
	$SingleUser = ($((Write-Host ("Enter the EmailAddress, PhoneNumber  e.g joy@dev.io,+12065551234 : ") -NoNewline -ForegroundColor Yellow) ;Read-Host)).Trim().Split(",").Trim()

	if($SingleUser){
		$EmailAddress = $SingleUser[0].Trim()
		$PhoneNumber  = $SingleUser[1].Trim()

		$ActionResults = Set-UserPhoneNumber -EmailAddress $EmailAddress -PhoneNumber $PhoneNumber
		$CompletedAndFailedObjects += $ActionResults

		$CompletedAndFailedObjects | Export-csv ".\PhoneNumberAssignmentResults_$((Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')).csv" -NoTypeInformation
	}else {
		Write-Host "`n`nNo information is provided, run again `n" -ForegroundColor Red
	}	
}

########## Completed