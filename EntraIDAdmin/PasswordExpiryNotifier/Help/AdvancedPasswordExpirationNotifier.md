# Advanced Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Detailed Component Design](#detailed-component-design)
4. [Implementation Details](#implementation-details)
5. [Configuration Requirements](#configuration-requirements)
6. [Security Considerations](#security-considerations)
7. [Error Handling and Logging](#error-handling-and-logging)
8. [Performance Considerations](#performance-considerations)
9. [Deployment Instructions](#deployment-instructions)
10. [Maintenance and Monitoring](#maintenance-and-monitoring)

## Overview

The Password Expiry Notification System is a PowerShell-based solution designed to proactively alert users about their upcoming password expirations in Microsoft Entra ID (formerly Azure AD). By automating this process, organizations can reduce helpdesk tickets, enhance security, and improve user experience.

This system leverages Microsoft Graph API to retrieve password expiration details and delivers customized email notifications using Graph API or SMTP. It supports multiple authentication methods, including client secrets and certificate-based authentication, ensuring secure and flexible deployment.

The Password Expiry Notification System is a PowerShell-based solution designed to:

- Monitor user password expiration dates in Microsoft Entra ID (formerly Azure AD)
- Send proactive email notifications to users whose passwords are nearing expiration
- Support multiple authentication methods for Microsoft Graph API access
- Provide flexible email delivery options (Graph API or SMTP)
- Maintain comprehensive logging and error handling

Key features include:

- Multi-method authentication fallback system
- Dynamic batch processing for efficient user processing
- Configurable notification thresholds and content
- Log rotation and retention management
- Support for both certificate-based and secret-based authentication

## System Architecture

### High-Level Components

1. **Authentication Module**
   - Handles connection to Microsoft Graph using multiple authentication methods
   - Implements fallback mechanism for authentication failures

2. **User Processing Engine**
   - Retrieves user data from Microsoft Entra ID
   - Filters users based on password policies and expiration criteria
   - Calculates remaining days until password expiration

3. **Notification System**
   - Generates personalized email content from templates
   - Supports multiple delivery methods (Graph API and SMTP)
   - Implements retry logic for failed deliveries

4. **Logging Framework**
   - Provides configurable log rotation
   - Supports multiple log levels (INFO, WARNING, ERROR)
   - Includes detailed error context for troubleshooting

### Data Flow

1. System loads configuration from JSON file
2. Establishes connection to Microsoft Graph using preferred authentication method
3. Retrieves all users and their password policies
4. Filters users based on expiration criteria
5. For each qualifying user:
   - Generates personalized email content
   - Delivers notification via configured method
   - Logs results
6. Performs cleanup and disconnection

## Detailed Component Design

### 1. Authentication Module

#### Connect-AuthMgGraph Function

- **Purpose**: Establishes connection to Microsoft Graph with multiple authentication options
- **Supported Methods**:
  - Client Secret
  - Certificate Thumbprint
  - Certificate Subject Name
  - PFX Certificate File
- **Fallback Mechanism**: Automatically attempts alternative methods if primary fails
- **Security**: Ensures proper credential handling and secure string conversion

#### Get-GraphAuthAccessToken Function

- **Purpose**: Obtains access token for Graph API operations
- **JWT Implementation**: Generates signed JWT tokens for certificate authentication
- **Token Management**: Handles token expiration and renewal

### 2. User Processing Engine

#### User Retrieval and Filtering

- Retrieves all users with essential properties:

  ```powershell
  Get-MgUser -All -Property DisplayName, PasswordPolicies, UserPrincipalName, LastPasswordChangeDateTime
  ```

- Filters users based on:
  - Domain-specific password policies
  - Password expiration status
  - Non-expired passwords

#### Expiration Calculation

- Computes remaining days until expiration:

  ```powershell
  $daysUntilExpiration = $policyHashTable[$userDomain] - ($today - $_.LastPasswordChangeDateTime).Days
  ```

- Calculates exact expiration date for notifications

### 3. Notification System

#### Email Content Generation

- Uses HTML templates with placeholder replacement
- Extracts subject from template content
- Supports dynamic content insertion (username, days remaining)

#### Delivery Methods

1. **Microsoft Graph API**
   - Uses `SendMail` API endpoint
   - Implements proper message construction with headers
   - Includes fallback to PowerShell cmdlet if REST fails

2. **SMTP Configuration**
   - Supports both authenticated and relay scenarios
   - Configurable ports and security options

### 4. Logging Framework

#### Write-Log Function

- **Features**:
  - Automatic log rotation based on size
  - Configurable retention policy
  - Detailed error context (including line numbers)
  - Multi-level logging (INFO, WARNING, ERROR)
- **Implementation**:
  - Uses timestamped entries
  - Maintains consistent formatting
  - Handles large volumes efficiently

## Implementation Details

### Core Functions

#### Get-UserPasswordPolicyConfig

```powershell
function Get-UserPasswordPolicyConfig {
    param (
        [Parameter(Mandatory)] 
        $UserInfo
    )
    return $UserInfo.PasswordPolicies -match "None"
}
```

- **Purpose**: Checks if user has no password policy
- **Input**: User object from Graph API
- **Output**: Boolean indicating policy status

#### Get-LastPasswordChangeDateTime

```powershell
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
```

- **Purpose**: Safely retrieves password change timestamp
- **Error Handling**: Gracefully handles missing data

#### Get-EmailContent

```powershell
function Get-EmailContent {
    param (
        [string]$EmailBodyPath,
        [string]$UserDisplayName,
        [int]$RemainingDays
    )
    # Implementation...
}
```

- **Template Processing**: Replaces placeholders with user-specific data
- **Validation**: Verifies template file existence
- **Output**: Structured object with subject and body

### Main Program Flow

1. **Configuration Validation**
   - Checks required files exist
   - Validates authentication method selection
   - Verifies SMTP configuration

2. **Authentication Setup**
   - Attempts multiple auth methods in sequence
   - Falls back to alternative methods on failure
   - Retrieves necessary tokens

3. **User Processing**
   - Retrieves all users with necessary properties
   - Filters based on domain policies and expiration
   - Calculates expiration metrics

4. **Notification Delivery**
   - Processes users in optimized batches
   - Generates personalized content
   - Delivers via selected method
   - Logs all operations

5. **Cleanup**
   - Disconnects Graph sessions
   - Finalizes logs

## Configuration Requirements

### Configuration File (Config.ps1)

Required settings:

```powershell
$Config = @{
    # Graph API Authentication
    TenantID = "your-tenant-id"
    ClientID = "your-client-id"
    GraphAuthMethod = "ClientAppSecret" # or "CertThumbprint", "CertSubject", "PfxCertFile"
    
    # Method-specific settings
    ClientSecret = "for-client-secret-method"
    CertThumbprint = "for-cert-thumbprint"
    CertSubject = "for-cert-subject"
    PfxCertFilePath = "path\to\cert.pfx"
    PfxCertPassword = "cert-password"
    
    # Email Settings
    SMTPServiceType = "MSgraphAPI" # or "LegacySMTPAuth", "SMTPRelay"
    MailSender = "sender@domain.com"
    
    # SMTP-specific settings
    SMTPServer = "smtp.server.com"
    SMTPPort = 587
    SMTPUsername = "optional"
    SMTPPassword = "optional"
}
```

### Email Template (PasswordExpiryEmailTemplate.html)

Requirements:

- HTML format
- Should contain placeholders:
  - `[User's Name]`
  - `[RemainingDaysUntilExpiration]`
- Should include subject in `<h2>` tags

## Security Considerations

1. **Credential Handling**
   - Client secrets are converted to secure strings
   - Certificate private keys are protected
   - No credentials are logged

2. **Authentication**
   - Supports most secure methods (certificates preferred)
   - Implements proper token management

3. **Data Protection**
   - Minimizes data retention
   - Secures log files

4. **Transport Security**
   - Enforces TLS for SMTP
   - Uses HTTPS for Graph API

## Error Handling and Logging

### Error Handling Strategy

- Try/catch blocks for all major operations
- Fallback mechanisms for critical functions
- Graceful degradation where possible

### Logging Features

- Automatic log rotation (3MB default)
- Backup log retention (2 files default)
- Detailed error context including:
  - Timestamps
  - Error levels
  - Line numbers for errors
  - Full error messages

### Notification Failure Handling

- Failed email attempts are logged
- System continues processing other users
- No retry logic (to prevent spamming)

## Performance Considerations

### Batch Processing

- Dynamic batch sizing based on user count
- Small batches (5) for few users
- Larger batches (up to 50) for many users
- Balances memory usage and performance

### Efficient Data Retrieval

- Uses selective property retrieval from Graph:

  ```powershell
  Get-MgUser -All -Property DisplayName, PasswordPolicies, UserPrincipalName, LastPasswordChangeDateTime
  ```

- Minimizes data transfer

### Memory Management

- Processes users in batches
- Clears intermediate variables
- Disposes of objects properly

## Deployment Instructions

### Prerequisites

- PowerShell 5.1 or later
- Microsoft Graph PowerShell module
- Required permissions:
  - User.Read.All (for user enumeration)
  - Mail.Send (for Graph API email)
  - 

### Installation Steps

1. Create deployment directory
2. Copy script files:
   - Main PowerShell script
   - Config.ps1
   - PasswordExpiryEmailTemplate.html
3. Modify configuration file with your settings
4. Test with small user subset

### Scheduling

- Recommended to run weekly
- Can be scheduled via Task Scheduler
- Consider timezone differences for notifications

## Maintenance and Monitoring

### Regular Checks

- Monitor log files for errors
- Verify successful runs
- Check authentication token expiration

### Update Procedures

- Review Microsoft Graph API changes
- Update PowerShell modules regularly
- Test after any configuration changes

### Troubleshooting Guide

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Authentication failures | Expired credentials | Update configuration |
| Missing users | Insufficient permissions | Grant User.Read.All |
| Email delivery failures | SMTP configuration | Verify server settings |
| Template errors | Missing placeholders | Check HTML template |

## Appendix: Complete Function Reference

### Get-UserPasswordPolicyConfig

- Determines if user has password policy set to "None"

### Get-LastPasswordChangeDateTime

- Retrieves password change timestamp with null checking

### Write-Log

- Comprehensive logging with rotation and retention

### Connect-AuthMgGraph

- Multi-method Graph authentication connector

### Get-GraphAuthAccessToken

- Handles token acquisition with JWT support

### Get-EmailContent

- Generates personalized email from template

### Send-MailGraphAPI

- Delivers email via Graph API with fallback

### Send-MailSMTPRelay

- SMTP delivery with multiple configuration options
