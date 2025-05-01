# Email Folder Migration Tool
## Overview

This PowerShell script enables efficient migration of email messages between folders within the same Microsoft Exchange Online mailbox using Microsoft Graph API. It provides options for both individual and batch processing of message moves with comprehensive error handling and detailed progress reporting.

## Prerequisites

1. **PowerShell 5.1 or higher** installed on your system
2. **Microsoft Graph PowerShell SDK** modules installed and configured
3. **Appropriate Microsoft 365 permissions** to access and modify user mailboxes
4. **Authentication** to Microsoft Graph API completed before running the script

## Getting Started

### Installation

1. Save the script to your local environment
2. Connect to Microsoft Graph API with appropriate permissions:
   ```powershell
   Connect-MgGraph -Scopes "Mail.ReadWrite", "Mail.ReadWrite.Shared"
   ```

### Basic Usage

```powershell
.\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive"
```

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| **UserId** | String | Yes | - | The UPN (email) of the target mailbox user |
| **SourceFolderName** | String | Yes | - | The display name of the source folder (e.g., 'Inbox') |
| **DestinationFolderName** | String | Yes | - | The display name of the destination folder |
| **ResultSize** | Integer | No | 999 | Maximum number of messages to retrieve per API call |
| **BatchMove** | Switch | No | False | Switch to move messages in batches instead of individually |
| **BatchSize** | Integer | No | 5 | Number of messages per batch move (valid range: 1-20) |
| **DelayInSeconds** | Integer | No | 1 | Delay between each batch move |
| **ResultDisplayFrequency** | Integer | No | 10 | How often to display move progress (e.g., every 10 messages) |
| **MaxRetryAttempts** | Integer | No | 3 | Maximum number of retry attempts for failed moves |
| **EnableLogging** | Boolean | No | True | Enable logging of failed moves to a CSV log file |

## Examples

### Example 1: Basic Migration
Move all messages from Inbox to Archive folder:
```powershell
.\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive"
```

### Example 2: Batch Processing
Move messages in batches of 10 with a 2-second delay between batches:
```powershell
.\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive" -BatchMove -BatchSize 10 -DelayInSeconds 2
```

### Example 3: Customized Display and Retry Logic
Customize the progress display frequency and retry attempts:
```powershell
.\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive" -ResultDisplayFrequency 20 -MaxRetryAttempts 5
```

### Example 4: Disable Logging
Run the migration without generating failure logs:
```powershell
.\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive" -EnableLogging $false
```

## Performance Considerations

- **Individual Moves**: Better for smaller migrations and when maximum reliability is required
- **Batch Moves**: More efficient for large migrations but may have higher failure rates
- **BatchSize**: Lower values (5-10) provide better reliability, higher values (10-20) provide better performance
- **DelayInSeconds**: Increase this value if experiencing throttling or rate limiting issues

## Error Handling and Logging

The script includes comprehensive error handling with these features:

1. **Automatic Retries**: Failed moves are automatically retried based on the MaxRetryAttempts parameter
2. **CSV Logging**: Failed moves are logged to a CSV file with the format `MoveFailures-{UserId}-{timestamp}.csv`
3. **Detailed Progress**: Visual progress indicators show completed/failed operations
4. **Failure Analysis**: The CSV log includes message ID, subject, received date, failure reason, and number of attempts

## Log File Format

The failure log CSV file contains the following columns:
- **MessageId**: Unique identifier of the message
- **Subject**: Email subject
- **ReceivedDateTime**: When the message was received
- **Reason**: Error message or status code
- **Attempts**: Number of retry attempts made

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Ensure you're connected to Microsoft Graph with appropriate permissions
   - Verify the user has the necessary access rights to both folders

2. **Folder Not Found**
   - Double-check folder names (they are case-sensitive)
   - Use Get-MailboxFolders to list available folders

3. **Rate Limiting/Throttling**
   - Increase DelayInSeconds parameter
   - Reduce BatchSize
   - Consider running the script during off-peak hours

4. **Permission Issues**
   - Ensure your account has Mail.ReadWrite permissions
   - For shared or delegated mailboxes, ensure Mail.ReadWrite.Shared is granted

## Advanced Usage

### Processing Very Large Folders

For folders with tens of thousands of messages, consider these approaches:

1. **Run in multiple batches**:
   ```powershell
   # First run - process first 5000 messages
   .\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive" -ResultSize 5000 -BatchMove
   
   # Subsequent runs if needed
   ```

2. **Increase result display frequency for less verbose output**:
   ```powershell
   .\Move-MailAcrossFolders -UserId "user@example.com" -SourceFolderName "Inbox" -DestinationFolderName "Archive" -ResultDisplayFrequency 100 -BatchMove
   ```

## Notes and Limitations

- The script moves messages between folders in the same mailbox only
- The maximum batch size supported by Microsoft Graph API is 20 messages
- For very large folders (>10,000 messages), the script may take significant time to complete
- The script retrieves basic message properties (id, subject, receivedDateTime) to minimize memory usage
- After migration, confirm all messages are properly moved before deleting any data

## Credits

Developed by Daniel Tetteh (TechJollof@gmail.com)
Available on GitHub under MIT License terms

---

For questions, issues, or contributions, please contact the developer or submit issues through the GitHub repository.