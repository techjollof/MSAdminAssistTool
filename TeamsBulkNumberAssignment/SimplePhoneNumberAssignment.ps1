
# make users have been assigned PhoneSytem license
# have a csv file with the following colunms EmailAddress, PhoneNumber

$UsersAcc = import-csv "$home\Downloads\NumebrAssignment.csv"
$CompletedAndFailedObjects = @()


Write-Host "#############  Checking and Assigning numbers to users #############" -ForegroundColor Green

$UsersAcc | ForEach-Object -Parrall {
	
	$acc = $_

	# verify if Phone system is assigned and enble enterprise voice
	Set-CsPhoneNumberAssignment -Identity $acc.EmailAddress -EnterpriseVoiceEnabled $true -EA SilentlyContinue -EV LicenseUserError
	
	if($LicenseUserError){
		$CompletedAndFailedObjects += [PSCustomObject]@{
			EmailAddress	= 	$acc.EmailAddress
			TeamType	    = 	$acc.PhoneNumber
			AssignStatus	=	"Failed"
			FailureReason 	= 	$LicenseUserError[0].ErrorDetails.Message	
		}
		
	}else{
		# Assign number and if number success update table
		Set-CsPhoneNumberAssignment -Identity $acc.EmailAddress -PhoneNumber $acc.PhoneNumber -PhoneNumberType DirectRouting -EA SilentlyContinue -EV NumberAsignError

        $CompletedAndFailedObjects += [PSCustomObject]@{
			EmailAddress	= 	$acc.EmailAddress
			TeamType	    = 	$acc.PhoneNumber
			AssignStatus	=	if($NumberAsignError){"Failed"}else{"Succeeded"}
			FailureReason 	= 	if($NumberAsignError){$LicenseUserError[0].ErrorDetails.Message}else{"Succeeded"}	
		}
	}

    $cu = $CompletedAndFailedObjects[-1] 
    write-host ("{0}`t`t`t`t`t{1} " -f $cu.AssignStatus,$cu.EmailAddress) -ForegroundColor Yellow

}
if($CompletedAndFailedObjects){
	$CompletedAndFailedObjects | Export-csv "$Home\Downloads.\PhoneNumberAssignmentResults_$((Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')).csv" -NoTypeInformation
}