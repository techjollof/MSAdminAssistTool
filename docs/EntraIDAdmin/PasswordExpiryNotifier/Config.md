# Configuration for Email Service & MS Graph Authentication

## Overview

This configuration file is used to set up the email service for sending emails via Microsoft Graph API or SMTP. It allows for multiple authentication methods to access the Microsoft Graph API and configure SMTP settings.

---

## Authentication and Authorization

Configuration for email service to authenticate and authorize with Microsoft Graph API.

### TenantID

- **Description**: Azure AD Tenant ID required for Microsoft Graph authentication.
- **Usage**: This is the unique identifier for your Azure Active Directory instance. It is essential for all authentication methods.
- **Example**: `"TenantID": "your-tenant-id"`

### ClientId

- **Description**: Client ID (App ID) for the registered Azure AD app.
- **Usage**: The Client ID identifies the application registered in Azure Active Directory that will interact with Microsoft Graph API.
- **Example**: `"ClientId": "your-client-id"`

### ClientSecret

- **Description**: Client secret key generated for your Azure AD app (required if using `ClientAppSecret` authentication).
- **Usage**: This is a confidential value used along with the `ClientId` to authenticate the application with Microsoft Graph. It should be kept secure.
- **Example**: `"ClientSecret": "your-client-secret"`

### CertThumbprint

- **Description**: Certificate thumbprint for authentication via certificate (required for `CertThumbprint` method).
- **Usage**: A thumbprint is a unique identifier for a certificate, used for certificate-based authentication. This is typically used in environments where certificates are more secure than secrets.
- **Example**: `"CertThumbprint": "ABC1234567890"`

### CertSubject

- **Description**: Subject name of the certificate for authentication (required for `CertSubject` method).
- **Usage**: This is the subject of the certificate you wish to use for authentication. It helps locate the correct certificate in the certificate store.
- **Example**: `"CertSubject": "CN=your-cert-name"`

### PfxCertFilePath

- **Description**: Path to the PFX certificate file for authentication (required for `PfxCertFile` method).
- **Usage**: Specifies the location of the PFX certificate file used for authentication. This file contains both the public and private keys required for authentication.
- **Example**: `"PfxCertFilePath": "C:\\path\\to\\your\\certificate.pfx"`

### PfxCertPassword

- **Description**: Password to unlock the PFX certificate file (required for `PfxCertFile` method).
- **Usage**: The password is needed to decrypt the PFX file. It must match the password set when the PFX file was created.
- **Example**: `"PfxCertPassword": "your-pfx-password"`

---

## Mail Sender Configuration

Configuration for the email sender and authentication method.

### MailSender

- **Description**: Email address used to send emails (must be valid within your tenant).
- **Usage**: The email address you will use to send messages. This should be a verified email within your Microsoft tenant (either via Microsoft Graph API or SMTP).
- **Example**: `"MailSender": "your-email@domain.com"`

### GraphAuthMethod

- **Description**: Preferred authentication method for Microsoft Graph API. Choose from `ClientAppSecret`, `CertThumbprint`, `CertSubject`, or `PfxCertFile`.
- **Usage**: Select one of the available authentication methods for Graph API. Each method has its own set of required parameters (e.g., `ClientSecret` for `ClientAppSecret`, `CertThumbprint` for `CertThumbprint`).
- **Options**:
  - `ClientAppSecret`: Uses the `ClientId` and `ClientSecret` for authentication.
  - `CertThumbprint`: Uses a certificate thumbprint to authenticate.
  - `CertSubject`: Uses a certificate subject to authenticate.
  - `PfxCertFile`: Uses a PFX certificate file and its password for authentication.
- **Example**: `"GraphAuthMethod": "ClientAppSecret"`

---

## SMTP Support

Parameters for SMTP-based email service configuration.

### SMTPServer

- **Description**: SMTP server address. For example, `smtp.office365.com` for Office 365 email services.
- **Usage**: This defines the server used to send email messages. It should be an address of a valid SMTP server.
- **Example**: `"SMTPServer": "smtp.office365.com"`

### SMTPPort

- **Description**: Port used for SMTP communication. `587` is recommended for TLS encryption.
- **Usage**: SMTP communication generally happens over ports `25`, `465`, or `587`. Port `587` is recommended for secure TLS communication.
- **Example**: `"SMTPPort": 587`

### SMTPUsername

- **Description**: SMTP username (email address) for authentication, required for `LegacySMTPAuth`.
- **Usage**: This is the email address used for authenticating against the SMTP server.
- **Example**: `"SMTPUsername": "your-email@domain.com"`

### SMTPPassword

- **Description**: SMTP password for authentication, required for `LegacySMTPAuth`.
- **Usage**: The password associated with the `SMTPUsername`. It is used to authenticate the user against the SMTP server.
- **Example**: `"SMTPPassword": "your-email-password"`

---

## Services Options

Defines the type of service to use for sending emails.

### SMTPServiceType

- **Description**: Choose the email service type. Options are `LegacySMTPAuth`, `MSgraphAPI`, or `SMTPRelay`.
- **Usage**: This determines the email sending method.
  - `LegacySMTPAuth`: Use traditional SMTP authentication.
  - `MSgraphAPI`: Use Microsoft Graph API for sending emails.
  - `SMTPRelay`: Use an SMTP relay without authentication.
- **Example**: `"SMTPServiceType": "LegacySMTPAuth"`

---

## Notes

- **Security**: Always keep sensitive values such as `ClientSecret`, `PfxCertPassword`, `SMTPPassword`, etc., in a secure location (e.g., environment variables or a secrets manager).
- **Validation**: Ensure that the `MailSender` email address and the SMTP credentials are valid within your tenant to avoid authentication issues.
- **Authentication Method**: Choose the authentication method based on your environment. For example, certificate-based methods are more secure and should be preferred for production environments.
- **Testing**: Test the configuration in a development environment before deploying to production to ensure that all settings are correct and functional.
