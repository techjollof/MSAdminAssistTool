

function Get-UserPasswordPolicyConfig {
    param (
        [Parameter(Mandatory)] 
        $UserInfo
    )
    return $UserInfo.PasswordPolicies -match "None"
}

function Get-LastPasswordChangeDateTime {
    param (
        $UserInfo
    )

    if ($UserInfo.LastPasswordChangeDateTime) {
        return $UserInfo.LastPasswordChangeDateTime
    }
    else {
        Write-Host "No time stamp for the $($UserInfo.UserPrincipalName)"
    }
    
}


function Write-Log {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",

        [int]$MaxLogSizeMB = 3, # Max log file size before rotation (in MB)
        [int]$MaxBackupLogs = 2   # Maximum number of backup logs to keep
    )

    # Define log file paths using $PSScriptRoot (cross-platform)
    $LogFile = Join-Path -Path $PSScriptRoot -ChildPath "PasswordExpiryLog.log"
    $LogPattern = Join-Path -Path $PSScriptRoot -ChildPath "PasswordExpiryLog_*.log"

    # Check log file size and rotate if necessary, rename, and delete old logs
    if (Test-Path -Path $LogFile) {
        $FileSizeMB = (Get-Item $LogFile).Length / 1MB
        if ($FileSizeMB -ge $MaxLogSizeMB) {
            # Rename the old log
            $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $BackupLogFile = Join-Path -Path $PSScriptRoot -ChildPath "PasswordExpiryLog_$Timestamp.log"
            Rename-Item -Path $LogFile -NewName $BackupLogFile -Force

            # Delete old logs
            $OldLogs = Get-ChildItem -Path $LogPattern | Sort-Object LastWriteTime -Descending
            if ($OldLogs.Count -gt $MaxBackupLogs) {
                $LogsToDelete = $OldLogs[$MaxBackupLogs..($OldLogs.Count - 1)]
                $LogsToDelete | ForEach-Object { Remove-Item -Path $_.FullName -Force }
            }
        }
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($Message -match "\[INFO\]|\[WARNING\]|\[ERROR\]") {
        $LogEntry = $Message  # Keep the message as is
    }
    elseif ($Level -eq "ERROR") {
        $LineNumber = $MyInvocation.ScriptLineNumber
        $LogEntry = "$Timestamp [$Level] - Line $LineNumber - $Message"
    }
    else {
        $LogEntry = "$Timestamp [$Level] ----- $Message"
    }


    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry
}

function Connect-AuthMgGraph {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ClientID,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ClientAppSecret", "CertThumbprint", "CertSubject", "PfxCertFile")]
        [string]$GraphAuthMethod,

        # Client Secret Authentication
        [Parameter(ParameterSetName = "ClientSecret", Mandatory = $true)]
        [string]$ClientSecret,

        # Certificate Thumbprint Authentication
        [Parameter(ParameterSetName = "CertThumbprint", Mandatory = $true)]
        [string]$CertThumbprint,

        # Certificate Subject Name Authentication
        [Parameter(ParameterSetName = "CertSubject", Mandatory = $true)]
        [string]$CertSubject,

        # Certificate File Authentication
        [Parameter(ParameterSetName = "PfxCertFile", Mandatory = $true)]
        [string]$CertPath,

        [Parameter(ParameterSetName = "PfxCertFile", Mandatory = $true)]
        [string]$CertPassword
    )

    try {
        
        # Disconnect existing session if connected with the same ClientId
        if (($mgContext = Get-MgContext) -and $mgContext.ClientId -eq $ClientID) {
            Disconnect-MgGraph > $null
            Write-Log "Disconnected existing Microsoft Graph session." 
        }
        

        # Set authentication parameters dynamically
        $Params = @{ TenantId = $TenantId; ClientId = $ClientID }

        switch ($GraphAuthMethod) {
            "PfxCertFile" {
                $Params["Certificate"] = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, (ConvertTo-SecureString $CertPassword -AsPlainText -Force), [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet
                )
            }
            "CertSubject" {
                $Cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -match "CN=$CertSubject" } | Select-Object -First 1
                if (-not $Cert) { 
                    Write-Log "Certificate with subject '$CertSubject' not found."  -Level ERROR 
                    return
                }
                $Params["CertificateName"] = $CertSubject
            }
            "CertThumbprint" { 
                $Params["CertificateThumbprint"] = $CertThumbprint 
            }
            "ClientAppSecret" { 
                # Convert the Client Secret to a Secure String and create credentials
                $SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
                $Params["ClientSecretCredential"] = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientID, $SecureClientSecret
                $Params.Remove("ClientID")

            }
        }

        # Connect to Microsoft Graph
        Connect-MgGraph @Params -NoWelcome 
        Write-Log "Connected to Microsoft Graph using $GraphAuthMethod!" 
    }
    catch { Write-Log "Error: $_" ERROR }
}

function Get-GraphAuthAccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantID,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(ParameterSetName = "ClientSecret", Mandatory = $true)]
        [string]$ClientSecret,

        [Parameter(ParameterSetName = "CertThumbprint", Mandatory = $true)]
        [string]$CertThumbprint,

        [Parameter(ParameterSetName = "CertPfx", Mandatory = $true)]
        [string]$CertPath,

        [Parameter(ParameterSetName = "CertPfx", Mandatory = $true)]
        [string]$CertPassword,

        [Parameter(ParameterSetName = "CertSubject", Mandatory = $true)]
        [string]$CertSubjectName
    )

    [string]$Scope = "https://graph.microsoft.com/.default"

    try {
        # ================================
        # Client Credentials (Client ID + Secret)
        # ================================
        if ($PSCmdlet.ParameterSetName -eq "ClientSecret") {
            $tokenBody = @{
                client_id     = $ClientId
                client_secret = $ClientSecret
                grant_type    = "client_credentials"
                scope         = $Scope
            }
            $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" `
                -Method POST `
                -Body $tokenBody `
                -ContentType "application/x-www-form-urlencoded"

            if ($tokenResponse.access_token) {
                return @{
                    "Authorization" = "Bearer $($tokenResponse.access_token)"
                    "Content-Type"  = "application/json"
                }
            }
            else {
                Write-Log "Failed to obtain token using Client Secret." -Level ERROR
                return $null
            }
        }

        # ================================
        # Load Certificate (Thumbprint, File, or Subject Name)
        # ================================
        $cert = $null
        $storeLocations = @("CurrentUser", "LocalMachine")

        # Search for Certificate by Thumbprint or Subject Name in both stores
        foreach ($storeLocation in $storeLocations) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", $storeLocation)
            $store.Open("ReadOnly")

            if ($PSCmdlet.ParameterSetName -eq "CertThumbprint") {
                $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $CertThumbprint } | Select-Object -First 1
            }
            elseif ($PSCmdlet.ParameterSetName -eq "CertSubject") {
                $cert = $store.Certificates | Where-Object { $_.Subject -like "*$CertSubjectName*" -and $_.HasPrivateKey } | Select-Object -First 1
            }

            $store.Close()

            if ($cert) { break }  # Stop searching if found
        }

        # Load from PFX File
        if ($PSCmdlet.ParameterSetName -eq "CertPfx") {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
                $CertPath,
                $CertPassword,
                @(
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet,
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet,
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
                )
            )
        }

        # Verify the certificate
        if (-not $cert) {
            Write-Error "Certificate not found or invalid."
            return $null
        }
        if (-not $cert.HasPrivateKey) {
            Write-Error "The certificate does not contain a private key."
            return $null
        }

        # ================================
        # Generate JWT for Certificate-Based Authentication
        # ================================
        $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        if (-not $privateKey) {
            Write-Log "Failed to retrieve the private key from the certificate." -Level ERROR
            return $null
        }

        # Create JWT header
        $jwtHeader = @{
            alg = "RS256"
            typ = "JWT"
            x5t = [Convert]::ToBase64String($cert.GetCertHash())
        } | ConvertTo-Json -Compress

        # Create JWT payload
        $jwtPayload = @{
            aud = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"
            exp = [int](([DateTimeOffset]::Now.AddMinutes(10)).ToUnixTimeSeconds())  # Expiration (10 mins)
            iss = $ClientId
            sub = $ClientId
            jti = [guid]::NewGuid().ToString()
        } | ConvertTo-Json -Compress

        # Base64 encode header & payload
        $jwtHeaderBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($jwtHeader))
        $jwtPayloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($jwtPayload))

        # Create the data to be signed
        $jwtToSign = "$jwtHeaderBase64.$jwtPayloadBase64"

        # Sign the JWT using the private key
        $signedJwt = [Convert]::ToBase64String(
            $privateKey.SignData([Text.Encoding]::UTF8.GetBytes($jwtToSign), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        )

        # Final JWT
        $clientAssertion = "$jwtHeaderBase64.$jwtPayloadBase64.$signedJwt"

        # Request body for OAuth token
        $tokenBody = @{
            client_id             = $ClientId
            client_assertion      = $clientAssertion
            client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
            grant_type            = "client_credentials"
            scope                 = $Scope
        }

        # Request access token
        $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" `
            -Method POST `
            -Body $tokenBody `
            -ContentType "application/x-www-form-urlencoded"

        if ($tokenResponse.access_token) {
            return @{
                "Authorization" = "Bearer $($tokenResponse.access_token)"
                "Content-Type"  = "application/json"
            }
        }
        else {
            Write-Log "Failed to obtain token using Certificate Authentication." -Level ERROR
            return $null
        }
    }
    catch {
        Write-Log "Error while requesting token: $_" -Level ERROR
        return $null
    }
}

function Get-EmailContent {
    param (
        [string]$EmailBodyPath,
        [string]$UserDisplayName,
        [int]$RemainingDays
        # [String]$PasswordExpirationDate
    )

    if (-Not (Test-Path $EmailBodyPath)) {
        Write-Error "File not found: $EmailBodyPath"
        return $null
    }

    # Read HTML Content from File  and Replace placeholders with actual values (e.g., User's Name, Remaining Days)
    $body = Get-Content -Path $EmailBodyPath -Raw
    $body = $body -replace "\[User's Name\]", $UserDisplayName
    $body = $body -replace "\[RemainingDaysUntilExpiration\]", $RemainingDays
    # $body = $body -replace "\[PasswordExpirationDate\]", $PasswordExpirationDate

    # Extract subject from the <h2> tag (assuming the subject is inside an <h2> tag)
    if ($body -match '<h2>(.*?)</h2>') {
        $subject = $matches[1]  # Extracted subject
    }
    else {
        Write-Error "No subject found in <h2> tag in HTML file."
        return $null
    }

    # Return the subject and the email body content
    return @{
        "Subject" = $subject
        "Body"    = $body
    }
}

function Send-MailGraphAPI {
    param (
        [Parameter(Mandatory)]
        [string]$MailSender, # Sender email address

        [Parameter(Mandatory)]
        [string[]]$MailRecipients, # Recipient email addresses

        [Parameter(Mandatory)]
        [hashtable]$APIAuthHeaders, # Authentication headers

        [Parameter(Mandatory)]
        [string]$Subject, # Email subject

        [Parameter(Mandatory)]
        [string]$Body  # Email body (HTML content)
    )

    # Child function for fallback email sending
    function Send-MailFallback {
        param (
            [string]$MailSender,
            [hashtable]$MailObject
        )

        try {
            # Ensure the Microsoft Graph SDK command is available
            if (-not (Get-Command -Name Send-MgUserMail -ErrorAction SilentlyContinue)) {
                Write-Log "Send-MgUserMail command not found. Please install the Microsoft.Graph, specifically 'Import-Module Microsoft.Graph.Users.Actions' if you done need all." -Level "ERROR"
                return
            }

            # Send the email using Microsoft Graph PowerShell SDK
            Send-MgUserMail -UserId $MailSender -BodyParameter $MailObject
            Write-Log "Fallback: Email sent using Send-MgUserMail."
        }
        catch {
            Write-Log -Message "Fallback email sending failed: $_" -Level ERROR
        }
    }

    # Convert recipients into the required format
    $ToRecipientsArray = @()
    foreach ($Email in $MailRecipients) {
        $ToRecipientsArray += @{
            emailAddress = @{
                address = $Email
            }
        }
    }

    # Construct the email object
    $MailObject = @{
        message         = @{
            subject                = $Subject
            body                   = @{
                contentType = "HTML"
                content     = $Body
            }
            toRecipients           = $ToRecipientsArray  # Assign multiple recipients
            internetMessageHeaders = @(
                @{
                    name  = "x-custom-header-password-expiry-notification"
                    value = "ResetYourPassword"
                }
            )
        }
        saveToSentItems = $true
    }


    # Convert the email object to JSON
    $BodyJsonSend = $MailObject | ConvertTo-Json -Depth 10 -Compress

    # Attempt to send email using Microsoft Graph API (REST)
    try {
        $URLsend = "https://graph.microsoft.com/v1.0/users/$MailSender/sendMail"
        Invoke-RestMethod -Method POST -Uri $URLsend -Headers $APIAuthHeaders -Body $BodyJsonSend -ContentType "application/json"
    }
    catch {
        Write-Log "Error sending email via Graph API: $_" -Level ERROR
        Send-MailFallback -MailSender $MailSender -MailObject $MailObject
    }
}


# legacy SMTP
function Send-MailSMTPRelay {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)][string]$MailSender,
        [Parameter(Mandatory, Position = 1)][string[]]$MailRecipients,
        [string[]]$CCRecipients,
        [string[]]$BCCRecipients,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body,
        
        [Parameter(Mandatory)][string]$SMTPServer,
        [ValidateSet(25, 465, 587)][int]$SMTPPort = 587,
        [PSCredential]$Credential,  
        
        [string[]]$Attachments,
        [switch]$EnableSSL, # Set a default value
        [int]$Timeout = 10000,
        [switch]$TestConnection
    )

    try {
        $SMTPClient = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
        $SMTPClient.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
        $SMTPClient.Timeout = $Timeout

        if ($Credential) {
            $SMTPClient.Credentials = $Credential.GetNetworkCredential()
        }
        else {
            $SMTPClient.UseDefaultCredentials = $true
        }

        if ($EnableSSL -or $SMTPPort -ne 25) {
            $SMTPClient.EnableSsl = $true  
        }

        if ($TestConnection) {
            $SMTPClient.SendAsyncCancel()
            Write-Host "SMTP connection test successful" -ForegroundColor Green
            return
        }

        # Build email message
        $MailMessage = New-Object System.Net.Mail.MailMessage
        $MailMessage.From = New-Object System.Net.Mail.MailAddress($MailSender)

        $MailRecipients | Where-Object { $_ -match '^[^@]+@[^@]+\.[^@]+$' } | ForEach-Object { 
            $MailMessage.To.Add($_) 
        }
        
        if ($CCRecipients) {
            $CCRecipients | Where-Object { $_ -match '^[^@]+@[^@]+\.[^@]+$' } | ForEach-Object { 
                $MailMessage.CC.Add($_) 
            }
        }
        
        if ($BCCRecipients) {
            $BCCRecipients | Where-Object { $_ -match '^[^@]+@[^@]+\.[^@]+$' } | ForEach-Object { 
                $MailMessage.Bcc.Add($_) 
            }
        }
        
        $MailMessage.Subject = $Subject
        $MailMessage.Body = $Body
        $MailMessage.IsBodyHtml = $true

        if ($Attachments) {
            $Attachments | Where-Object { Test-Path $_ } | ForEach-Object {
                $MailMessage.Attachments.Add((New-Object System.Net.Mail.Attachment($_)))
            }
        }

        $SMTPClient.Send($MailMessage)
        $MailMessage.Dispose()
        
    }
    catch {
        Write-Warning "Failed to send email: $_"
    }
}


####################### main program ########################

########### Data Validation

# Load the JSON configuration file and email content
$scriptPath = $PSScriptRoot
$configFile = Join-Path -Path $scriptPath -ChildPath "Config.ps1"
$emailContentFile = Join-Path -Path $scriptPath -ChildPath "PasswordExpiryEmailTemplate.html"

. $configFile
# Validate file existence and load config file
if (-Not (Test-Path $configFile) -or -Not (Test-Path $emailContentFile)) {
    Write-Log "Configuration or email content file not found." -Level "ERROR"
    exit
}

# Validate Graph authentication methods
$validGraphAuthMethods = @("ClientAppSecret", "CertThumbprint", "CertSubject", "PfxCertFile")
if (-not ($config.GraphAuthMethod) -or [string]::IsNullOrWhiteSpace($config.GraphAuthMethod) -or ($config.GraphAuthMethod -notin $validGraphAuthMethods)) {
    Write-Log "Either configuration file is: 1) Missing 'GraphAuthMethod' property. 2) The property is null or an empty string. 3) An invalid value has been selected. Allowed values: 'ClientAppSecret', 'CertThumbprint', 'CertSubject', 'PfxCertFile'." -Level "ERROR"
    exit
}

# Validate SMTP service type
$validSMTPTypes = @("MSgraphAPI", "LegacySMTPAuth", "SMTPRelay")
if (-not ($config.SMTPServiceType) -or [string]::IsNullOrWhiteSpace($config.SMTPServiceType) -or ($config.SMTPServiceType -notin $validSMTPTypes)) {
    Write-Log "Either configuration file is: 1) Missing 'SMTPServiceType' property. 2) The property is null or an empty string. 3) An invalid value has been selected. Allowed values: 'MSgraphAPI', 'LegacySMTPAuth', 'SMTPRelay'." -Level "ERROR"
    exit
}

# Define required keys based on the SMTP service type
$requiredKeys = if ($config.SMTPServiceType -eq "MSgraphAPI") {
    @("TenantID", "ClientID", "ClientSecret", "MailSender")
}
else {
    @("MailSender", "SMTPServer", "SMTPPort")
}

# Check required keys
foreach ($key in $requiredKeys) {
    if (-not ($config.$key) -or [string]::IsNullOrWhiteSpace($config.$key)) {
        Write-Log "Missing required configuration value: $key. Check the config file." -Level "ERROR"
        exit
    }
}


########### Establishing MS Graph connection ###########

# Assign values from config
$TenantID = $config.TenantID
$ClientId = $config.ClientID
$GraphAuthMethodPreference = $config.GraphAuthMethod

# Define authentication methods in priority order
$GraphAuthMethods = @($GraphAuthMethodPreference) + ($validGraphAuthMethods | Where-Object { $_ -ne $GraphAuthMethodPreference })

# Store authentication parameters in a dictionary
$AuthParams = @{
    "ClientAppSecret" = @{ ClientSecret = $config.ClientSecret }
    "CertThumbprint"  = @{ CertThumbprint = $config.CertThumbprint }
    "CertSubject"     = @{ CertSubject = $config.CertSubject }
    "PfxCertFile"     = @{ CertPath = $config.PfxCertFilePath; CertPassword = $config.PfxCertPassword }
}

# Flag to track successful connection
$Connected = $false
$TokenRetrieved = $false

foreach ($AuthMethod in $GraphAuthMethods) {
    try {
        Write-Log "Attempting connection using $AuthMethod..." 

        # Validate if method has required parameters
        $GraphParams = @{ TenantId = $TenantID; ClientID = $ClientId; GraphAuthMethod = $AuthMethod }
        if ($AuthParams[$AuthMethod]) { 
            $GraphParams += $AuthParams[$AuthMethod]
        }
        else {
            continue 
        }

        # Attempt connection
        Connect-AuthMgGraph @GraphParams
        $graphContext = Get-MgContext

        if ($graphContext) {
            Write-Log "Successfully connected using $AuthMethod!"
            $Connected = $true
        } 
        else {
            Write-Log "Failed to connect using $AuthMethod. $_" -Level ERROR
            continue  # Try next method if connection fails
        }

        break  # Stop trying after success
    }
    catch {
        Write-Log "Failed using $AuthMethod. $_ Trying next available method to connect MSGraph..." -Level ERROR
    }
}

# Final check if connection was never established
if (-not $Connected) {
    Write-Log "Unable to authenticate using any method. Check the configuration file." -Level ERROR
    exit 1
}

#get graph auth token headers
if ($config.SMTPServiceType -eq "MSgraphAPI") {
    
    # Attempt to authenticate using each method in order
    foreach ($AuthMethod in $GraphAuthMethods) {
        try {
            Write-Log "Attempting connection using $AuthMethod..."

            # Prepare authentication parameters dynamically
            $TokenParams = @{ TenantId = $TenantID; ClientID = $ClientId }
            $TokenParams += $AuthParams[$AuthMethod]  # Add method-specific parameters

            # Call the existing function to get the token
            $accessToken = Get-GraphAuthAccessToken @TokenParams
        
            if ($accessToken) {
                Write-Log "Successfully connected using $AuthMethod!"
                $TokenRetrieved = $true
                break # Stop trying after success
            }
        }
        catch {
            Write-Log "Failed using [$AuthMethod]. $($error[0]) Trying next available method to get token o..." -Level ERROR
        }
    }

    # Final check if connection was never established
    if (-not $TokenRetrieved) {
        Write-Log "Unable to authenticate using any method. Check the configuration file." -Level ERROR
        exit 1
    }
}



######### Processing Mail parameters

if ($config.SMTPServiceType -ne "MSgraphAPI") {
    # Setup SMTP Relay parameters
    $RelayParams = @{}
    $SMTPKeys = @("MailSender", "SMTPServer", "SMTPPort")
    foreach ($key in $SMTPKeys) {
        if ($config.$key) {
            $RelayParams[$key] = $config.$key
        }
    }
    

    # Handle SMTP credentials securely
    if ($config.SMTPPassword -and $config.SMTPServiceType -eq "LegacySMTPAuth") {
        $UserName = if ([string]::IsNullOrEmpty($config.SMTPUsername)) { $config.MailSender } else { $config.SMTPUsername }
        $SecurePassword = ConvertTo-SecureString $config.SMTPPassword -AsPlainText -Force
        $SMTPCredential = New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword)
        $RelayParams["Credential"] = $SMTPCredential
    }
}

########### Get all users

# Get and filter users and password policies
try {

    $allUsers = Get-MgUser -All -Property DisplayName, PasswordPolicies, UserPrincipalName, LastPasswordChangeDateTime
    $orgPasswordPolicies = Get-MgDomain | Select-Object ID, PasswordValidityPeriodInDays

    # Check if any domain has a PasswordValidityPeriodInDays <= 730
    $validPolicies = $orgPasswordPolicies | Where-Object { $_.PasswordValidityPeriodInDays -le 730 }
    # Exit if no valid policies are found
    if (-not $validPolicies) {
        Write-Log "No domains found with PasswordValidityPeriodInDays <= 730. Exiting..."
        exit
    }
    # Convert to key-value hash table
    $policyHashTable = @{}
    foreach ($validPolicy in $validPolicies) {
        $policyHashTable[$validPolicy.ID] = $validPolicy.PasswordValidityPeriodInDays
    }

    $today = Get-Date
    $validityNotificationPeriod = @($config.PasswordExpirationThreshold)  # Ensure it's an array

    Write-Host "This is number of day "
    

    $filteredUsers = $allUsers | Where-Object {
        $userDomain = $_.UserPrincipalName.Split('@')[-1]
        # Check if user's domain has a password policy we care about
        if ($policyHashTable.ContainsKey($userDomain)) {
            $passwordAge = ($today - $_.LastPasswordChangeDateTime).Days
            $daysUntilExpiration = $policyHashTable[$userDomain] - $passwordAge
            # Return true if password is not set to never expire and is within the validity period
        ($_.PasswordPolicies -ne "DisablePasswordExpiration") -and ($daysUntilExpiration -in $validityNotificationPeriod)
        }
        else {
            # If the domain is not in the hash table, exclude the user
            $false
        }
    } | Select-Object DisplayName, PasswordPolicies, UserPrincipalName, LastPasswordChangeDateTime, @{
        Name       = 'daysUntilExpiration';
        Expression = {
            $userDomain = $_.UserPrincipalName.Split('@')[-1]
            $policyHashTable[$userDomain] - ($today - $_.LastPasswordChangeDateTime).Days
        }
    }, @{
        Name       = 'PasswordExpirationDate';
        Expression = {
            $userDomain = $_.UserPrincipalName.Split('@')[-1]
            $_.LastPasswordChangeDateTime.AddDays($policyHashTable[$userDomain])
        }
    }
    Write-Log "The total number of uses $($allUsers.Count) and filtered are $($filteredUsers.Count)" 


    return

}
catch {
    Write-Log "Error retrieving user data: $_" -Level "ERROR"
    exit
}



############ Processing all users

# Dynamic batch size calculation
$logMessages = @()
$totalUsers = $filteredUsers.Count

$batchSize = if ($totalUsers -lt 50) { 5 } else { [math]::Min([math]::Max([math]::Floor($totalUsers / 10), 5), 50) }
$counter = 0  # Track processed users

foreach ($user in $filteredUsers) {
    
    $emailContent = Get-EmailContent -EmailBodyPath $emailContentFile -UserDisplayName $user.DisplayName -RemainingDays $user.daysUntilExpiration -PasswordExpirationDate

    # $emailContent.Body > ".\testUsers\$($user.DisplayName).html"
    try {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($config.SMTPServiceType -eq "MSgraphAPI") {
            Send-MailGraphAPI -MailSender $config.MailSender -MailRecipients $user.UserPrincipalName -APIAuthHeaders $accessToken -Subject $emailContent.Subject -Body $emailContent.Body
            $logMessages += "$($Timestamp) [INFO] ----- Email successfully sent to $($user.UserPrincipalName) via MS Graph. Subject: $($emailContent.Subject)"
        }
        else {
            $RelayParams["MailRecipients"] = $user.UserPrincipalName
            $RelayParams["Body"] = $emailContent.Body
            $RelayParams["Subject"] = $emailContent.Subject + "SMTP"

            Send-MailSMTPRelay @RelayParams
            $logMessages += "$($Timestamp) [INFO] ----- Email successfully sent to $($user.UserPrincipalName) via SMTP Auth/Relay. Subject: $($emailContent.Subject)"
        }
        
    }
    catch {
        Write-Log "Failed to send email to $($user.UserPrincipalName): $_" -Level "ERROR"
    }

    $counter++
    
    # Write logs in batches
    if ($counter % $batchSize -eq 0) {
        $logMessages.GetType()
        Write-Log ($logMessages -join "`n" )
        $logMessages = @()  # Clear batch
    }
    # }
}

# Write remaining logs if any
if ($logMessages.Count -gt 0) {
    # $logMessages.GetType()
    Write-Log ($logMessages -join "`n")
}

Disconnect-MgGraph
