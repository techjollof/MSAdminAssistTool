[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "CreateApp", HelpMessage = "The friendly name of the app registration")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(3, 128)]
    [String]$AppName,

    
    [Parameter(Mandatory = $true, ParameterSetName = "UpdateApp", HelpMessage = "The app ID of the existing app registration to update instead of creating a new one, must provide the app ID")]
    [guid]$AppObjectId,


    [Parameter(Mandatory = $false, HelpMessage = "The file path to your public key file (.cer)")]
    [String]$CertPath,


    [Parameter(Mandatory = $true, ParameterSetName = "UpdateApp", HelpMessage = "create a new client secret for the app registration or app update, a new client secret will be created")]
    [Parameter(Mandatory = $false, ParameterSetName = "CreateApp", HelpMessage = "create a new client secret for the app registration or app update, a new client secret will be created")]
    [switch]$CreateAppSecret,

    
    [Parameter(Mandatory = $false, HelpMessage = "Secret duration in months. Default is 6 months")]
    [Int]$SecretDuration = 6, # Default to 6 months if not specified

    [Parameter(Mandatory = $false, HelpMessage = "Your Azure Active Directory tenant ID")]
    [String]$TenantId,

    [Parameter(Mandatory = $false)]
    [Switch]$StayConnected = $false
)


# Auto-activate CreateAppSecret if in UpdateApp mode but not explicitly set
if ($PSCmdlet.ParameterSetName -eq "UpdateApp" -and -not $PSBoundParameters.ContainsKey('CreateAppSecret')) {
    $CreateAppSecret = $true
}

# Graph permissions constants
$graphResourceId = "00000003-0000-0000-c000-000000000000"
$UserReadAll = @{ Id = "df021288-bdef-4463-88db-98f22de89214"; Type = "Role" }
$GroupReadAll = @{ Id = "5b567255-7703-4780-807c-7be8301ae99b"; Type = "Role" }
$MailSend = @{ Id = "b633e1c5-b582-4048-a93e-9f11b44c7e96"; Type = "Role" }

$appAuthInfo = @{}
$today = Get-Date

# Get context for access to tenant ID
$context = Get-MgContext

# Connect to Microsoft Graph
try {
    if ($TenantId) {
        Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId $TenantId -ErrorAction Stop
    }
    else {
        Connect-MgGraph -Scopes "Application.ReadWrite.All" -ErrorAction Stop
    }
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    return
}


# Get application info
$script:AppInfo = if ($AppName) {
    Get-MgApplication -Filter "DisplayName eq '$AppName'" -Property DisplayName, AppId, Id, PasswordCredentials, KeyCredentials -ErrorAction SilentlyContinue
}
else {
    Get-MgApplication -ApplicationId $AppObjectId -Property DisplayName, AppId, Id, PasswordCredentials, KeyCredentials -ErrorAction SilentlyContinue
}

$appAuthInfo["AppName"] = $script:AppInfo.DisplayName

function New-AppCreation {
    try {
        # Create new app registration
        $appRegistration = New-MgApplication -DisplayName $AppName -SignInAudience "AzureADMyOrg" -Web @{ RedirectUris = "http://localhost" } -RequiredResourceAccess @{ ResourceAppId = $graphResourceId; ResourceAccess = $UserReadAll, $GroupReadAll, $MailSend }
        
        # Create corresponding service principal
        New-MgServicePrincipal -AppId $appRegistration.AppId -AdditionalProperties @{} | Out-Null
        Write-Host -ForegroundColor Cyan "New app registration and Service principal created with app ID" $appRegistration.AppId

        $appAuthInfo["AppId"] = $appRegistration.AppId 
        $appAuthInfo["TenantId"] = $context.TenantId
        $appAuthInfo["AppObjectId"] = $appRegistration.Id
        $appAuthInfo["AppName"] = $appRegistration.DisplayName
        $appAuthInfo["AdminConsentUrl"] = "https://login.microsoftonline.com/$($context.TenantId)/adminconsent?client_id=$($appRegistration.AppId)"

        $AppCredentials = Update-AppAuthenticationMethods -AppObjectId $appRegistration.Id

        if ($AppCredentials) {
            $appAuthInfo["ConnectGraph"] = "Connect-MgGraph -ClientId """ + $appRegistration.AppId + """ -TenantId """ + $context.TenantId + """ -ClientSecret """ + $AppCredentials.ClientSecret + """"
            Write-Host -ForegroundColor Green "App credentials created successfully with app ID: $($appRegistration.AppId)"
        }

        return $appRegistration
    }
    catch {
        Write-Error "Error creating app registration: $_"
        return $null
    }
}

function Update-AppAuthenticationMethods {
    param(
        [Parameter(Mandatory = $true)]
        [guid]$AppObjectId
    ) 
    
    $appAuthInfo["AppObjectId"] = $AppObjectId

    try {
        if ($CertPath) {
            # Load cert and update the app registration with the new certificate
            # Get the current date
            $today = Get-Date

            # Retrieve the app's existing certificates
            $ValidCerts = $script:AppInfo.KeyCredentials | Where-Object { $_.EndDateTime -ge $today }


            # Update the application, keeping only valid certificates
            Update-MgApplication -ApplicationId $AppObjectId -KeyCredentials $ValidCerts



            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
            Update-MgApplication -ApplicationId $AppObjectId -KeyCredentials @(@{ Type = "AsymmetricX509Cert"; Usage = "Verify"; Key = $cert.RawData }) | Out-Null
            Write-Host -ForegroundColor Cyan "Certificate added to app registration"
            $appAuthInfo["Thumbprint"] = $cert.Thumbprint
            $appAuthInfo["Subject"] = $cert.Subject
        }

        if ($CreateAppSecret) {
            # Create a new client secret
            $script:AppInfo.PasswordCredentials | ForEach-Object { 
                if ($_.EndDateTime -lt $today) { 
                    Write-Host -ForegroundColor Red "The existing client secret is expired on $($_.EndDateTime).......... Removing $($_.KeyId)"
                    Remove-MgApplicationPassword -ApplicationId $AppObjectId -KeyId $_.KeyId -Confirm:$false -ErrorAction SilentlyContinue
                }
            }

            $passwordCred = @{
                DisplayName = "ClientSecret$(Get-Random)"
                EndDateTime = (Get-Date).AddMonths($SecretDuration)
            }

            $secret = Add-MgApplicationPassword -ApplicationId $AppObjectId -PasswordCredential $passwordCred
            $appAuthInfo["ClientSecretName"] = $passwordCred.DisplayName
            $appAuthInfo["ClientSecret"] = $secret.SecretText
            $appAuthInfo["ClientSecretExpires"] = $passwordCred.EndDateTime
        }

        return $appAuthInfo
    }
    catch {
        Write-Error "Error updating app authentication methods: $_"
        return $null
    }
}

# Main execution logic
if ($PSCmdlet.ParameterSetName -eq "CreateApp") {
    if ($script:AppInfo) {
        Write-Host -ForegroundColor Red "$(if ($script:AppInfo.count -gt 1) {"Multiple"} else {"An"}) app with the name '$AppName' already exists. Please choose a different 'AppName' or set the value of 'AppObjectId' parameter by using the existing list and update credentials`n"
        Write-Host -ForegroundColor Magenta "Existing app Info:`n"
        $script:AppInfo | Format-Table -Property DisplayName, ID

        Write-Host -ForegroundColor Yellow "To update the existing app with the new certificate, and the new secret, use the 'AppObjectID'`n"
        return
    }
    else {
        $appRegistration = New-AppCreation 
    }
}
elseif ($PSCmdlet.ParameterSetName -eq "UpdateApp" -and $AppObjectId -ne $null) {
    $AppCredentials = Update-AppAuthenticationMethods -AppObjectId $AppObjectId
    if ($AppCredentials) {
        $appAuthInfo["AppId"] = $script:AppInfo.AppId
        Write-Host -ForegroundColor Green "App registration updated successfully with app ID: $($script:AppInfo.AppId)"
    }
    else {
        Write-Host -ForegroundColor Red "Failed to update app registration with app ID: $($AppObjectId)"
        return
    }
}


# Export app info if available
if ($appAuthInfo -and $appAuthInfo.Count -gt 0) {
    $ExportFilePath = "$PSScriptRoot\$($appAuthInfo.AppName)_AppInfo.txt"

    # Convert app info to string
    $ExportData = $appAuthInfo | Out-String

    if (Test-Path $ExportFilePath) {
        # Append to existing file
        Add-Content -Path $ExportFilePath -Value "`n$(Get-Date): New authentication detail added`n===============================================================" -Encoding UTF8
        Add-Content -Path $ExportFilePath -Value "$ExportData" -Encoding UTF8
        Write-Host -ForegroundColor Yellow "App details appended to: $ExportFilePath"
    } else {
        # Create a new file and write data
        $ExportData | Out-File -FilePath $ExportFilePath -Encoding UTF8
        Write-Host -ForegroundColor Cyan "App details exported to: $ExportFilePath"
    }
}


# Disconnect if not staying connected
if (-not $StayConnected) {
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected from Microsoft Graph`n"
}
else {
    Write-Host -ForegroundColor Yellow "The connection to Microsoft Graph is still active. To disconnect, use Disconnect-MgGraph`n"
}