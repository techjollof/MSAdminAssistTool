# Password Expiry Notification System  

## **Overview**  

The **Password Expiry Notification System** is a PowerShell-based solution designed to help organizations proactively notify users about their upcoming password expirations in **Azure AD/Office 365** environments. By sending timely email reminders using **Microsoft Graph API** or **SMTP**, it helps prevent login disruptions and reduces helpdesk requests related to password resets.  

---

## **Key Features**  


Your formatting is already excellent! Here’s a slightly refined version with minor tweaks for better readability while keeping your bolding preference intact:  

---

### ✅ **Authentication & Email Delivery Options**  

#### 🔐 **Multiple Authentication Methods for Microsoft Graph API**  

The script supports various authentication methods for secure communication with Microsoft Graph API:  

- **Client Secret** (`ClientAppSecret`)  
- **Certificate Authentication:**  
  - Thumbprint-based Authentication (`CertThumbprint`)  
  - Subject Name Authentication (`CertSubject`)  
  - PFX Certificate File (`PfxCertFile`)  

#### 📧 **Flexible Email Delivery Options**  

The script offers multiple email-sending methods to suit different environments:  

- **Microsoft Graph API** (`MSgraphAPI`) – Recommended for modern, secure authentication  
- **SMTP Relay** (`SMTPRelay`) – Works with or without authentication  
- **Legacy SMTP Authentication** (`LegacySMTPAuth`) – For environments requiring traditional SMTP authentication  

#### ✉️ **Email Notification Process**  

1. Generates email content using a customizable HTML template  
2. Delivers notifications using the configured method:  
   - **Microsoft Graph API** (`MSgraphAPI`)  
   - **SMTP Authentication** (`LegacySMTPAuth`)  
   - **SMTP Relay** (`SMTPRelay`)  

#### 🛡️ **Smart Password Policy Handling**  

- Automatically detects password expiration policies for different domains  
- Filters users intelligently based on expiration rules to avoid unnecessary notifications  

#### 🎨 **Customizable Email Templates**  

- Supports a fully customizable HTML template for personalized notifications  
- Allows placeholders for dynamic user-specific details (e.g., `{UserName}`, `{ExpiryDate}`)  

#### 📜 **Robust Logging & Monitoring**  

- Detailed execution logs for tracking sent emails, authentication attempts, and errors  
- Automatic log rotation to prevent excessive file growth  

#### 🚀 **Optimized for Large-Scale Environments**  

- Batch processing prevents overwhelming email servers with bulk notifications  
- Dynamic batch size adjustment ensures efficient email delivery  

---

## Requirements

### **System**

📌 **Windows OS:** Needs windows OS (not tested on MAC OS)
📌 **PowerShell Version:** 5.1 or later  
📌 **Required Module:** Microsoft.Graph (install if not already available)  
📌 **Permissions:** Entra ID (Azure AD) app registration with email-sending capabilities


### API Permission required

- **User.Read.All**: allows you to retrieve users
- **Mail.Send**: sending of email if using Graph API for email
- **Domain.Read.All**: Get password expiry configuration, to read password policies

### **Installing Required MS Graph Modules**

Install only required Microsoft Graph API packages 

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Users.Actions, Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser -Repository PSGallery -Force
```

Install the full Microsoft Graph PowerShell module

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

## **Installation & Setup**  

### **1️⃣ Download & Extract the Script**  

Download and extract the script files to your preferred location.  

### **2️⃣ Configure Settings (Config.ps1)**  

Modify `Config.ps1` to define authentication details, email settings, and other preferences.  

```powershell
$Config = @{
    # Microsoft Graph Authentication Configuration
    TenantID = "your-tenant-id"
    ClientID = "your-client-id"
    GraphAuthMethod = "ClientAppSecret" # Options: ClientAppSecret, CertThumbprint, CertSubject, PfxCertFile
    
    # Authentication Details
    ClientSecret = "your-client-secret"  # If using ClientAppSecret
    CertThumbprint = "certificate-thumbprint"  # If using CertThumbprint
    CertSubject = "certificate-subject-name"  # If using CertSubject
    PfxCertFilePath = "path\to\certificate.pfx"  # If using PFX file
    PfxCertPassword = "pfx-password"

    # Email Configuration
    SMTPServiceType = "MSgraphAPI" # Options: MSgraphAPI, LegacySMTPAuth, SMTPRelay
    MailSender = "noreply@yourdomain.com"

    # SMTP Settings (If not using Microsoft Graph)
    SMTPServer = "smtp.yourdomain.com"
    SMTPPort = 587
    SMTPUsername = "your-smtp-username"
    SMTPPassword = "your-smtp-password"
    EnableSSL = $true

    # Options: 7 days, 14 days, you can add more options as needed but these are the most common.
    PasswordExpirationThreshold = @(7, 14)
}
```

### **3️⃣ Customize the Email Template**  

Modify `PasswordExpiryEmailTemplate.html` to match your organization's branding.  

⚠ **Do NOT change placeholder values**, as they are dynamically replaced in the script.  

- `[User's Name]` → Auto-filled with the user's name  
- `[RemainingDaysUntilExpiration]` → Auto-filled with the remaining days  

Example Email Content:  
```html
<h2>Password Expiration Notice</h2>
<p>Dear [User's Name],</p>
<p>Your password will expire in <b>[RemainingDaysUntilExpiration]</b> days.</p>
<p>Please change it to avoid login issues.</p>
```

---

## **File Structure & Description**  

```bash
📂 PasswordExpiryNotifier/
├── 📜 PasswordExpiryNotifier.ps1          # Main script for sending password expiry notifications
├── ⚙️ Config.ps1                          # Configuration file for authentication and email settings
├── ✉️ PasswordExpiryEmailTemplate.html    # Customizable HTML email template for notifications
├── 📄 PasswordExpiryLog.log               # Auto-generated log file for tracking execution details
├── 🔑 RegisterAppOnly.ps1                 # Script to register an Azure AD app for authentication
├── 🔒 CreateSelfSignedCertificate.ps1     # Script to generate a self-signed certificate for secure authentication
├── 📖 README.md                           # Previous version of the README (archived)
├── 📖 AutoMations_AppInfo.txt             # is is automatically generated by when new is generate or credentials update
└── 📂 Docs/                               # Documentation folder
    ├── ⚙️ Config.md                       # Explanation of configuration settings
    ├── 🔒 CreateSelfSignedCertificate.md  # Guide to generating a self-signed certificate
    ├── 🔑 RegisterAppOnly.md              # Instructions for registering an Azure AD app
    ├── 📖 README.md                       # Main project documentation
    ├── ExtensiveTechnicalReadMe.md         # Extensive read me technical documents
```

## **Usage Instructions**  

### **🔹 Running the Script**  

Manually run the script in PowerShell:  
```powershell
.\PasswordExpirationNotifier.ps1
```

OR, schedule it **daily** using **Windows Task Scheduler**:  

1. Open **Task Scheduler** → **Create a New Task**  
2. Set the trigger to run **every day at 9 AM**  
3. Set the action to run:  
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\PasswordExpirationNotifier.ps1"
   ```

---

## **How It Works**  

✔ **Loads configuration settings** (`Config.ps1`)  
✔ **Authenticates with Microsoft Graph API** or **SMTP**  
✔ **Retrieves users** whose passwords are about to expire  
✔ **Generates personalized email notifications**  
✔ **Sends emails via Microsoft Graph API or SMTP**  
✔ **Logs all actions, errors, and sent emails**  

---

## **Logging & Troubleshooting**  

📌 **Log File Location:** `PasswordExpiryLog.log`  

🔍 **Common Issues & Fixes**  

| **Issue** | **Possible Cause** | **Solution** |
|-----------|--------------------|--------------|
| Users not receiving emails | Incorrect email sender or recipient email | check the logs for more info, verify the sender email `Config.ps1` settings, you also check message trace |
| Authentication failure | Expired secret/certificate | Update credentials in `Config.ps1` |
| Script not running in Task Scheduler | Execution policy restrictions | Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| No users being processed | Incorrect domain policies or no user password is about to expired | Check Entra ID password expiration settings using `Get-MgDomain` or check and make users are not assign `DisablePasswordExpiration` on password policies |

To check logs, open `PasswordExpiryLog.log` and look for:  
```
2025-04-01 09:30:00 [INFO] ----- Email successfully sent to user@domain.com
2025-04-01 09:35:00 [ERROR] ----- Authentication failed using ClientAppSecret
```

---

## **Security Best Practices**  

🔐 **Protect Credentials & Secrets**  

- Do NOT store passwords in plain text. **Use Azure Key Vault** if possible.  
- Restrict access to **Config.ps1** using NTFS permissions.  

🔐 **Limit Azure AD Permissions**  

- Use the **least privileged permissions** necessary for Microsoft Graph API.  
- Regularly audit **application permissions**.  

🔐 **Enable Secure Email Sending**  

- Prefer **Microsoft Graph API** over SMTP for improved security.  
- If using SMTP, **enable SSL/TLS** and strong authentication.  

---

## **Performance Optimizations**  

⚡ **Batch Processing**  

- Dynamically adjusts batch size to **prevent email server overload**.  

⚡ **Automatic Log Rotation**  

- **Log file size is limited to 3MB**.  
- **Older logs are archived automatically**.  

---

## **Support & Contact**  

📧 **IT Support:** techjollof@gmail.com  
📖 **Documentation:** check the help folder for each script documentation

---

## **Changelog**  

📅 **Version 1.0** (Initial Release)  

- Multiple authentication methods  
- Email notifications via Graph API & SMTP  
- Logging & batch processing  

📅 **Version 1.1** (Upcoming)  

- On-prem **Active Directory query support**  

---

## **License**  

📜 MIT License / Your Preferred License  

---

🚀 The **Password Expiry Notification System** ensures users are always aware of their password expiration dates, reducing disruptions and improving security.
