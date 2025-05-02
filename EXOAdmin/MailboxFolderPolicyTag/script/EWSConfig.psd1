@{
    # The name of the mailbox folder to stamp the policy on (e.g., Inbox subfolder)
    TargetFolderName = '3DaysMoveDataArchive'

    # The RawRetentionId (GUID) of the Archive or Retention tag to apply
    ArchiveOrRetentionTagRawRetentionId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    # The retention flag value retrieved via MFCMAPI (typically 1, 153, 23, etc.)
    RetentionFlagsValue = 153

    # The period (in days) after which data is moved/retained (from MFCMAPI tag settings)
    ArchiveOrRetentionPeriodInDays = 3

    # The initial domain of the Microsoft 365 tenant (e.g., contoso.onmicrosoft.com)
    TenantInitialDomain = 'JesusIsTheWay.onmicrosoft.com'

    # The Azure App (Enterprise Application) Client ID used for authentication with EWS
    AzureEWSApplicationClientId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

    # The file path (relative or absolute) to the list of user email addresses
    TargetUserAccountsCsv = 'UserAccounts.txt'

    # The location of the target folder — either in the Primary or Archive mailbox
    TargetFolderLocation = 'PrimaryMailBox'  # or 'ArchiveMailBox'

    # Specifies whether the policy is an Archive or Retention action
    ArchiveOrRetainAction = 'ArchiveAction'  # or 'RetentionAction'
}
