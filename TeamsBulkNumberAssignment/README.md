# TeamsBulkNumberAssignment

    Make sure users have been assigned Microsoft Phone System license
    Have a csv file with the following columns EmailAddress, PhoneNumber            
    Written by Daniel, if you have any error, reach out to me on techjollof@gmail.com
#### NO WARRANTY
    SAMPLE – AS IS, NO WARRANTY: This script assumes a connection teams powershell module

#### DESCRIPTION
	Assigning number in bulk or single user and results can be exported to csv file.
	Export results can separate file for both failed and succeeded or all together in a single file
#### BulkAssignment
	This is a switch parameter, if specified then the BulkAssignmentCsvData must be provided,
    if not present single user	action is performed.
#### PhoneNumberType
	The type of phone number to assign to the user or resource account. The supported values are DirectRouting, 
	CallingPlan, and OperatorConnect. When you acquire a phone number you will typically know which type it is.
	The default is none
#### BulkAssignmentCsvData
	Path to CSV file for bulk number assignment. Mandatory if the BulkAssignment parameter is specified
#### EXAMPLE 
This will perform assignment for one user by first requesting the value for PhoneNumberType else it will failed

```
 .\PhoneNumberAssignment.ps1
```

#### EXAMPLE 
This will perform assignment for one user
```
.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting
```
#### EXAMPLE
For bulk action specifing the source csv file directly

```
.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting -BulkAssignmentCsvData ".\NumebrAssignment.csv"
```
#### EXAMPLE
For bulk action using the BulkAssignment switch, this will proceed to request the BulkAssignmentCsvData path
```
.\PhoneNumberAssignment.ps1 -PhoneNumberType DirectRouting -BulkAssignment
```

#### OUTPUTS
Output from this cmdlet exports csv file which contains the results from your assign process

![Results CSV](.\Sample%20Results.png)


#### LINK
	if you have an error in running the script, you can refer to the following link
		https://social.technet.microsoft.com/wiki/contents/articles/38496.unblock-downloaded-powershell-scripts.aspx
	for more information
		https://learn.microsoft.com/en-us/powershell/module/teams/set-csphonenumberassignment?view=teams-ps
		https://learn.microsoft.com/en-us/microsoftteams/assign-change-or-remove-a-phone-number-for-a-user