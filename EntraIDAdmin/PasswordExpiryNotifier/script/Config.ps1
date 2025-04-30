$Config = @{
    # Entra ID Tenant ID required for Microsoft Graph authentication. 
    # This is a globally unique identifier for your tenant.
    TenantID         = ""

    # The application (client) ID for the Entra ID app registration. 
    # This uniquely identifies your app.
    ClientId         = ""

    # Secret key associated with your Entra ID application. 
    # Required for ClientAppSecret authentication. Keep this secure.
    ClientSecret     = ""

    # Thumbprint of the certificate stored in the local machine or user certificate store.
    # Used for certificate-based authentication.
    CertThumbprint   = "Value CertThumbprint for Graph authentication"

    # Subject name of the certificate used for authentication. 
    # The system will search for this certificate in the local store.
    CertSubject      = "Value CertSubject for Graph authentication"

    # File path to the PFX certificate used for authentication. 
    # This should point to a valid PFX file containing a private key.
    PfxCertFilePath  = "Value PfxCertFilePath for Graph authentication"

    # Password to unlock the PFX certificate file. 
    # This is required if using a PFX file for authentication.
    PfxCertPassword  = "Value PfxCertPassword for Graph authentication"

    # Email address used to send emails. This must be a valid mailbox within your tenant.
    MailSender       = "auto@domain.com"

    # Preferred authentication method for Microsoft Graph API. 
    # Options: 'ClientAppSecret', 'CertThumbprint', 'CertSubject', or 'PfxCertFile'.
    GraphAuthMethod  = "ClientAppSecret"

    # SMTP server address for sending emails. 
    # Use 'smtp.office365.com' for Office 365, or provide a custom SMTP server.
    SMTPServer       = "smtp.office365.com"

    # Port used for SMTP communication. 
    # Common values: 25 (unencrypted), 465 (SSL), or 587 (TLS).
    SMTPPort         = 587

    # SMTP username (email address) for authentication. 
    # Required if using 'LegacySMTPAuth'.
    SMTPUsername     = "auto@domain.com"

    # SMTP password for authentication. 
    # Required if using 'LegacySMTPAuth'. Store securely.
    SMTPPassword     = ""

    # Defines the email sending method. 
    # Options: 'LegacySMTPAuth' (traditional SMTP authentication), 
    # 'MSgraphAPI' (Microsoft Graph API), or 'SMTPRelay' (SMTP relay without authentication).
    SMTPServiceType  = "MSgraphAPI"

    # Password expiration threshold in days.
    # This is the number of days before the password expires that a notification will be sent.
    # Options: 7 days, 14 days, you can add more options as needed but these are the most common. You can 2 as well.
    PasswordExpirationThreshold = 7, 14
}
