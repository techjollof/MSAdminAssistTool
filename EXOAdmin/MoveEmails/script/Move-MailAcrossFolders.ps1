<#
.SYNOPSIS
    Moves email messages between folders in a user's mailbox using Microsoft Graph API.

.DESCRIPTION
    This script moves messages from a specified source folder to a destination folder in a user's mailbox.
    It supports both single-message move and batch move operations. 
    Features include automatic retry on failures, optional logging of failed moves, and periodic progress updates.

.PARAMETER UserId
    (Required) The UPN (email address) of the target mailbox user. Example: user@domain.com

.PARAMETER SourceFolderName
    (Required) The display name of the source folder (e.g., "Inbox", "Deleted Items").

.PARAMETER DestinationFolderName
    (Required) The display name of the destination folder.

.PARAMETER ResultSize
    (Optional) Maximum number of messages to retrieve per API call. Default is 999.

.PARAMETER BatchMove
    (Optional) Switch. If specified, moves messages in batches instead of one by one.

.PARAMETER BatchSize
    (Optional) Number of messages to include in each batch move. Default is 5. Allowed range: 1-20.

.PARAMETER DelayInSeconds
    (Optional) Delay (in seconds) between each batch move. Default is 1 second.

.PARAMETER ResultDisplayFrequency
    (Optional) How often to display move progress (e.g., every 50 messages). Default is 50.

.PARAMETER EnableLogging
    (Optional) Switch. If specified, logs failures to a CSV file in the script directory.

.EXAMPLE
    .\Move-MailAcrossFolders.ps1 -UserId "user@domain.com" -SourceFolderName "Alexa" -DestinationFolderName "Inbox" -BatchMove -BatchSize 10 -EnableLogging

    Moves all messages from the "Alexa" folder to the "Inbox" folder in batches of 10, with logging enabled.

.EXAMPLE
    .\Move-MailAcrossFolders.ps1 -UserId "admin@domain.com" -SourceFolderName "Sent Items" -DestinationFolderName "Inbox"

    Moves messages from the "Sent Items" folder to the "Inbox" folder one by one (default single message move).

.EXAMPLE
    .\Move-MailAcrossFolders.ps1 -UserId "user@domain.com" -SourceFolderName "Drafts" -DestinationFolderName "Sent Items" -BatchMove -BatchSize 5

    Moves messages from the "Drafts" folder to the "Sent Items" folder in batches of 5 messages. Does not log failures.

.NOTES
    Author: (Your Name)
    Version: 1.0
    Requires: Microsoft.Graph PowerShell module
    Pre-requisite: Connect-MgGraph must be authenticated before running this script.
#>


[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The UPN (email) of the target mailbox user.")]
    [string]$UserId,

    [Parameter(Mandatory = $true, HelpMessage = "The display name of the source folder (e.g., 'Inbox').")]
    # [ValidateNotNullOrWhiteSpace]
    [string]$SourceFolderName,

    [Parameter(Mandatory = $true, HelpMessage = "The display name of the destination folder.")]
    # [ValidateNotNullOrWhiteSpace]
    [string]$DestinationFolderName,

    [Parameter(HelpMessage = "Maximum number of messages to retrieve per API call. Default is 999.")]
    [int]$ResultSize = 999,

    [Parameter(HelpMessage = "Switch to move messages in batches instead of individually.")]
    [switch]$BatchMove,

    [Parameter(HelpMessage = "Number of messages per batch move. Valid range: 1-20.")]
    [ValidateRange(1, 20)]
    [int]$BatchSize = 10,

    [Parameter(HelpMessage = "Delay (in seconds) between each batch move. Default is 1 second.")]
    [int]$DelayInSeconds = 1,

    [Parameter(HelpMessage = "How often to display move progress (e.g., every 10 messages). Default is 10.")]
    [int]$ResultDisplayFrequency = 10,

    [Parameter(HelpMessage = "Maximum number of retry attempts for failed moves. Default is 3.")]
    [int]$MaxRetryAttempts = 3,

    [Parameter(HelpMessage = "Enable logging of failed moves to a CSV log file. Default is `$true.")]
    [bool]$EnableLogging = $true
)


# Set log file path in script root if logging is enabled
$global:LogFilePath = if ($EnableLogging) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Join-Path -Path $PSScriptRoot -ChildPath "MoveFailures-$($UserId)-$timestamp.csv"
}

# Function to write failure details into the CSV log
function Write-FailureLog {
    param (
        [Parameter(Mandatory)][object]$Entry
    )
    if ($EnableLogging -and $global:LogFilePath) {
        $Entry | Export-Csv -Path $global:LogFilePath -NoTypeInformation -Append -Force
    }
}


# Function: Get all folders
function Get-MailboxFolders {
    param ([Parameter(Mandatory)][string]$UserId)
    $allFolders = @()
    $nextLink = "/beta/users/$UserId/mailFolders?`$top=999"

    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        $allFolders += $response.value
        $nextLink = $response.'@odata.nextLink'
    }
    return $allFolders
}

# Function: Get all messages in a folder
function Get-AllMessagesInFolder {
    param (
        [Parameter(Mandatory)][string]$UserId,
        [Parameter(Mandatory)][string]$FolderId
    )

    $messages = New-Object System.Collections.Generic.List[Object]
    $selectFields = "id,subject,receivedDateTime"

    $nextLink = "/v1.0/users/$UserId/mailFolders/$FolderId/messages?`$top=$ResultSize&`$select=$selectFields"

    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Uri $nextLink
        $response.value | ForEach-Object { [void]$messages.Add($_) }
        $nextLink = $response.'@odata.nextLink'
    }
    return $messages
}

# Function: Write color message
function Write-Message {
    param ([string]$Message, [string]$Color = "Magenta")
    Write-Host " $Message" -ForegroundColor $Color
}

# Function: Write move summary
function Write-MessageMoveSummary {
    param (
        [hashtable]$SummaryData,
        [string]$Title
    )
    $Length = 100
    if ($Title) {
        $SideStars = [math]::Max(0, [math]::Floor(($Length - $Title.Length - 2) / 2))
        $Header = ('*' * $SideStars) + " " + $Title + " " + ('*' * $SideStars)
        if ($Header.Length -lt $Length) { $Header += '*' }
        Write-Host "`n$Header`n" -ForegroundColor Cyan
    }
    foreach ($key in $SummaryData.Keys) {
        Write-Host " $key : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($SummaryData[$key])" -ForegroundColor White
    }
    Write-Host ""
}



# ---------------- Move Individual Messages ----------------
function Move-Messages {
    param (
        [array]$Messages,
        [string]$UserId,
        [string]$DestinationFolderId
    )

    $total = $Messages.Count
    $totalSuccess = 0
    $totalFailed = 0
    $counter = 0

    Write-Message "`nStarting message move (Total: $total)...`n"

    foreach ($message in $Messages) {
        $counter++
        $uri = "https://graph.microsoft.com/v1.0/users/$UserId/messages/$($message.id)/move"
        $body = @{ destinationId = $DestinationFolderId } | ConvertTo-Json
        $headers = @{ "Content-Type" = "application/json" }

        $success = $false
        $attempt = 0

        while (-not $success -and $attempt -lt $MaxRetryAttempts) {
            try {
                $attempt++
                $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -Headers $headers -ErrorAction Stop

                if ($response.id) {
                    $success = $true
                    $totalSuccess++
                }
                else {
                    throw "Unexpected response: No ID returned."
                }
            }
            catch {
                if ($attempt -ge $MaxRetryAttempts) {
                    $totalFailed++
                    Write-FailureLog -Entry ([pscustomobject]@{
                        MessageId         = $message.id
                        Subject           = $message.subject
                        ReceivedDateTime  = $message.receivedDateTime
                        Reason            = $_.Exception.Message
                        Attempts          = $attempt
                    })
                }
                else {
                    Start-Sleep -Seconds 2
                }
            }
        }

        if ((($counter) % $ResultDisplayFrequency) -eq 0 -or ($counter -eq $total)) {
            Write-Message ("Complete — Messages moved: {0}/{1} — ✅ Success: {2} | ❌ Failed: {3}" -f $counter, $total, $totalSuccess, $totalFailed) -Color Yellow
        }
    }

    return [pscustomobject]@{
        TotalMessages = $total
        TotalSuccess  = $totalSuccess
        TotalFailed   = $totalFailed
    }
}

# ---------------- Move Messages in Batch ----------------
function Move-MessagesBatch {
    param (
        [array]$Messages,
        [string]$UserId,
        [string]$DestinationFolderId,
        [int]$BatchSize = 20
    )

    $totalMessages = $Messages.Count
    $chunks = [Math]::Ceiling($totalMessages / $BatchSize)
    $totalSuccess = 0
    $totalFailed = 0

    Write-Message "`nStarting batch move of $totalMessages messages (Batch size: $BatchSize, Total batches: $chunks)...`n"

    for ($i = 0; $i -lt $chunks; $i++) {
        $batchRequest = @()
        $startIndex = $i * $BatchSize
        $endIndex = [Math]::Min($startIndex + $BatchSize - 1, $totalMessages - 1)
        $batchMessages = $Messages[$startIndex..$endIndex]

        $batchCounter = 0
        foreach ($message in $batchMessages) {
            $batchCounter++
            $batchRequest += [PSCustomObject]@{
                id      = "$batchCounter"
                method  = "POST"
                url     = "/users/$UserId/messages/$($message.id)/move"
                headers = @{ "Content-Type" = "application/json" }
                body    = @{ destinationId = $DestinationFolderId }
            }
        }

        $BatchRequestBody = [PSCustomObject]@{ requests = $batchRequest } | ConvertTo-Json -Depth 10

        try {
            $result = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/$batch' -Body $BatchRequestBody -ContentType 'application/json' -ErrorAction Stop

            foreach ($response in $result.responses) {
                if ($response.status -ge 200 -and $response.status -lt 300) {
                    $totalSuccess++
                }
                else {
                    $totalFailed++
                    $failedMessage = $batchMessages[[int]$response.id - 1]
                    Write-FailureLog -Entry ([PSCustomObject]@{
                        MessageId = $failedMessage.id
                        Subject   = $failedMessage.subject
                        ReceivedDateTime = $failedMessage.receivedDateTime
                        Reason    = "Status code: $($response.status)"
                        Attempts  = 1
                    })
                }
            }

            # Fallback
            if ($totalFailed -gt 0) {
                $failedMessages = $batchMessages | Where-Object { $result.responses[$_.id - 1].status -ge 400 }
                if ($failedMessages.Count -gt 0) {
                    Write-Message "`nFalling back failed messages to individual move..."
                    $fallbackResult = Move-Messages -Messages $failedMessages -UserId $UserId -DestinationFolderId $DestinationFolderId
                    $totalSuccess += $fallbackResult.TotalSuccess
                    $totalFailed += $fallbackResult.TotalFailed
                }
            }
        }
        catch {
            Write-Warning "Batch $($i + 1) failed entirely: $_"
            foreach ($failed in $batchMessages) {
                $totalFailed++
                Write-FailureLog -Entry ([PSCustomObject]@{
                    MessageId = $failed.id
                    Subject   = $failed.subject
                    ReceivedDateTime = $failed.receivedDateTime
                    Reason    = "Batch failure: $_"
                    Attempts  = 1
                })
            }
        }

        if ((($i + 1) % $ResultDisplayFrequency) -eq 0 -or ($i -eq $chunks - 1)) {
            $movedMessages = [Math]::Min($startIndex + $batchMessages.Count, $totalMessages)
            Write-Message ("Batch {0}/{1} complete — Messages moved: {2}/{3} — ✅ Success: {4} | ❌ Failed: {5}" -f ($i + 1), $chunks, $movedMessages, $totalMessages, $totalSuccess, $totalFailed) -Color Yellow
        }

        Start-Sleep $DelayInSeconds
    }

    return [pscustomobject]@{
        TotalMessages = $totalMessages
        TotalSuccess  = $totalSuccess
        TotalFailed   = $totalFailed
    }
}

function DelayInSeconds {
    param (
        [array]$Messages,
        [string]$UserId,
        [string]$DestinationFolderId
    )

    $total = $Messages.Count
    $totalSuccess = 0
    $totalFailed = 0
    $counter = 0

    Write-Message "`nStarting message move (Total: $total)...`n"

    foreach ($message in $Messages) {
        $counter++
        $uri = "https://graph.microsoft.com/v1.0/users/$UserId/messages/$($message.id)/move"
        $body = @{ destinationId = $DestinationFolderId } | ConvertTo-Json
        $headers = @{ "Content-Type" = "application/json" }

        $success = $false
        $attempt = 0

        while (-not $success -and $attempt -lt $MaxRetryAttempts) {
            try {
                $attempt++
                $response = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -Headers $headers -ErrorAction Stop

                if ($response.id) {
                    $success = $true
                    $totalSuccess++
                }
                else {
                    throw "Unexpected response: No ID returned."
                }
            }
            catch {
                if ($attempt -ge $MaxRetryAttempts) {
                    $totalFailed++
                    Write-FailureLog -Entry ([pscustomobject]@{
                        MessageId         = $message.id
                        Subject           = $message.subject
                        ReceivedDateTime  = $message.receivedDateTime
                        Reason            = $_.Exception.Message
                        Attempts          = $attempt
                    })
                }
                else {
                    Start-Sleep -Seconds 2
                }
            }
        }

        if ((($counter) % $ResultDisplayFrequency) -eq 0 -or ($counter -eq $total)) {
            Write-Message ("Complete — Messages moved: {0}/{1} — ✅ Success: {2} | ❌ Failed: {3}" -f $counter, $total, $totalSuccess, $totalFailed) -Color Yellow
        }
    }

    return [pscustomobject]@{
        TotalMessages = $total
        TotalSuccess  = $totalSuccess
        TotalFailed   = $totalFailed
    }
}

# ---------------- Move Messages in Batch ----------------
function Move-MessagesBatch {
    param (
        [array]$Messages,
        [string]$UserId,
        [string]$DestinationFolderId,
        [int]$BatchSize = 20
    )

    $totalMessages = $Messages.Count
    $chunks = [Math]::Ceiling($totalMessages / $BatchSize)
    $totalSuccess = 0
    $totalFailed = 0

    Write-Message "`nStarting batch move of $totalMessages messages (Batch size: $BatchSize, Total batches: $chunks)...`n"

    for ($i = 0; $i -lt $chunks; $i++) {
        $batchRequest = @()
        $startIndex = $i * $BatchSize
        $endIndex = [Math]::Min($startIndex + $BatchSize - 1, $totalMessages - 1)
        $batchMessages = $Messages[$startIndex..$endIndex]

        $batchCounter = 0
        foreach ($message in $batchMessages) {
            $batchCounter++
            $batchRequest += [PSCustomObject]@{
                id      = "$batchCounter"
                method  = "POST"
                url     = "/users/$UserId/messages/$($message.id)/move"
                headers = @{ "Content-Type" = "application/json" }
                body    = @{ destinationId = $DestinationFolderId }
            }
        }

        $BatchRequestBody = [PSCustomObject]@{ requests = $batchRequest } | ConvertTo-Json -Depth 10

        try {
            $result = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/$batch' -Body $BatchRequestBody -ContentType 'application/json' -ErrorAction Stop

            foreach ($response in $result.responses) {
                if ($response.status -ge 200 -and $response.status -lt 300) {
                    $totalSuccess++
                }
                else {
                    $totalFailed++
                    $failedMessage = $batchMessages[[int]$response.id - 1]
                    Write-FailureLog -Entry ([pscustomobject]@{
                        MessageId = $failedMessage.id
                        Subject   = $failedMessage.subject
                        ReceivedDateTime = $failedMessage.receivedDateTime
                        Reason    = "Status code: $($response.status)"
                        Attempts  = 1
                    })
                }
            }
        }
        catch {
            Write-Warning "Batch $($i + 1) failed entirely: $_"
            foreach ($failed in $batchMessages) {
                $totalFailed++
                Write-FailureLog -Entry ([pscustomobject]@{
                    MessageId = $failed.id
                    Subject   = $failed.subject
                    ReceivedDateTime = $failed.receivedDateTime
                    Reason    = "Batch failure: $_"
                    Attempts  = 1
                })
            }
        }

        if ((($i + 1) % $ResultDisplayFrequency) -eq 0 -or ($i -eq $chunks - 1)) {
            $movedMessages = [Math]::Min($startIndex + $batchMessages.Count, $totalMessages)
            Write-Message ("Batch {0}/{1} complete — Messages moved: {2}/{3} — ✅ Success: {4} | ❌ Failed: {5}" -f ($i + 1), $chunks, $movedMessages, $totalMessages, $totalSuccess, $totalFailed) -Color Yellow
        }

        Start-Sleep $DelayInSeconds
    }

    return [pscustomobject]@{
        TotalMessages = $totalMessages
        TotalSuccess  = $totalSuccess
        TotalFailed   = $totalFailed
    }
}

function Write-MessageMoveSummary {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$SummaryData,
        [Parameter()][string]$Title
    )

    $Length = 100

    if ($Title) {
        $TitleLength = $Title.Length
        $SideStars = [math]::Max(0, [math]::Floor(($Length - $TitleLength - 2) / 2)) # -2 for spaces
        $Header = ('*' * $SideStars) + " " + $Title + " " + ('*' * $SideStars)

        if ($Header.Length -lt $Length) {
            $Header += '*'
        }

        Write-Host "`n$Header`n" -ForegroundColor Cyan
    }

    # Loop through and display the key-value pairs
    foreach ($key in $SummaryData.Keys) {
        Write-Host " $key : " -NoNewline -ForegroundColor Yellow
        Write-Host "$($SummaryData[$key])" -ForegroundColor White
    }

    Write-Host ""
}


function Write-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Color = "Magenta"

    )

    # Print the message in Cyan
    Write-Host " $Message" -ForegroundColor $Color
}

# Main execution block

$program = @'

####################################################################################################
#                                                                                                  #
#                          FOLDER TO FOLDER EMAIL MESSAGE MOVE (same mailbox)                      #
#                            Efficiently Move Messages Between Mail Folders                        #
#                                                                                                  #
#                                   Powered by Microsoft Graph API                                 #
#                       Developed by Daniel Tetteh (TechJollof@gmail.com) - github                 #
#                                                                                                  #
#                                      Under MIT License Terms                                     #
#                                                                                                  #
#                This script uses Microsoft Graph API for seamless message migration in the        #
#                 cloud. It's optimized for handling bulk operations and error management.         #
#                                                                                                  #
####################################################################################################

'@

Write-Message -Message $program -Color White


try {

    $allFolders = Get-MailboxFolders -UserId $UserId 

    # Resolve Folder IDs by display name
    $sourceFolder = $allFolders | Where-Object { $_.DisplayName -eq $SourceFolderName }
    $destinationFolder = $allFolders | Where-Object { $_.DisplayName -eq $DestinationFolderName }

    if (-not $sourceFolder -or -not $destinationFolder) {
        Write-Error "One or both folders were not found. Please check the folder names and try again."
        return
    }
    
    $sourceId = $sourceFolder.id
    $destinationId = $destinationFolder.id

    $Summary = @{
        "User ID"           = $UserId
        "Source Folder"     = $SourceFolderName
        "Destination Folder" = $DestinationFolderName
        "Source ID"         = $sourceId
        "Destination ID"     = $destinationId
    }
    
    Write-MessageMoveSummary -SummaryData $Summary -Title "Message Move Job Summary"

    # Retrieve all messages from source folder
    Write-Message "Retrieving messages from: $SourceFolderName...`n"

    $allMessages = Get-AllMessagesInFolder -UserId $UserId -FolderId $sourceId
    if (-not $allMessages -or $allMessages.Count -eq 0) {
        Write-Warning "No messages found in the source folder '$SourceFolderName'."
        return
    }

    $chunks = if($BatchMove){[Math]::Ceiling($allMessages.Count / $BatchSize)}else{1}

    # Move messages in parallel
    Write-Message "###### Processing message move"
    $moveDetail = @{
        "Total batches" = $($chunks)
        "Number of Items" = $($allMessages.Count)
    }

    Write-MessageMoveSummary -SummaryData $moveDetail

    # Return

    # Decide between batch move or single move
    if ($BatchMove) {
        Write-Message "`n############ Starting Batch Move" 
        $results = Move-MessagesBatch -Messages $allMessages -UserId $UserId -DestinationFolderId $destinationId -BatchSize $BatchSize -DelayInSeconds $DelayInSeconds -ResultDisplayFrequency $ResultDisplayFrequency    
    }
    else {
        Write-Message "`n############ Starting Single(1-by-1) Move" 
        $results = DelayInSeconds -Messages $allMessages -UserId $UserId -DestinationFolderID $destinationId
    }

    $processedMoveSummary = @{
        "Total Messages" = $results.TotalMessages  
        "Total Success"  = $results.TotalSuccess    
        "Total Failed"   = $results.TotalFailed    
    }

    Write-MessageMoveSummary -SummaryData $processedMoveSummary -Title "Processed move summary"

    
}
catch {
    Write-Error "`nError: $($_.Exception.Message)"
}
