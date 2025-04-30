# Function to read and convert parameters from a file
function Read-Parameters {
    param (
        [string]$FilePath
    )
    return Get-Content -Path $FilePath | ForEach-Object {
        ConvertFrom-StringData $_
    }
}

# Read the parameters from both files
$RetrieveValue = Read-Parameters ".\EWSRequiredParameters.txt"

# Check if parameters were retrieved successfully
if (-not $RetrieveValue) {
    Write-Host "Failed to retrieve parameters from EWSRequiredParameters.txt" -ForegroundColor Red
}


# Remapping values from the retrieved data set
$RetrieveParValue = @{
    TargetFolderName                     = $RetrieveValue.TargetFolderName
    ArchiveOrRetentionTagRawRetentionId  = $RetrieveValue.ArchiveOrRetentionTagRawRetentionId
    RetentionFlagsValue                  = $RetrieveValue.RetentionFlagsValue
    ArchiveOrRetentionPeriodInDays       = $RetrieveValue.ArchiveOrRetentionPeriodInDays
    TenantInitialDomain                  = $RetrieveValue.TenantInitialDomain
    AzureEWSApplicationClientId          = $RetrieveValue.AzureEWSApplicationClientId
    TargetUserAccountsCsv                = $RetrieveValue.TargetUserAccountsCsv
    TargetFolderLocation                  = $RetrieveValue.TargetFolderLocation
    ArchiveOrRetainAction                = $RetrieveValue.ArchiveOrRetainAction
}


# Call the next script with the parameter values
.\EWSMRMPolicyTagAssignment.ps1 @RetrieveParValue
