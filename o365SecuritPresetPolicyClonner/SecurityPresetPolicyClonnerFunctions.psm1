#Importing common functions
. $PSScriptRoot\CommonFunctions.ps1

# Set default log directory (in case the variable $LogFile has not been defined)
#$LogFile = ""
if ( ([string]::IsNullOrEmpty($LogFile)) -Or ($LogFile.Length -eq 0) ) {
    $LogDir = ".\Logs"
    $LogFileName = "DefaultLogFile_$(Get-Date -format dd-MM-yyyy)_$((Get-Date -format HH:mm:ss).Replace(":","-")).log"
    $LogFile = Join-path $LogDir $LogFileName
    #New-Item $LogFile
}

# get the default data from ps1 has file and update boolean and has data type
# the return results will be used for splatting
function Convert-ArrayToHashtable ([array]$ArrayStringData) {
    try {

        Write-ActivityLog -InformationType I "Loading  and processing predefiend data set $($ArrayStringData)" -LogFile $LogFile
        $Rawdata = ConvertFrom-StringData ([io.file]::ReadAllText($ArrayStringData) -join "`n")
        @($Rawdata.GetEnumerator()) | Where-Object {$_.Value  -in "true","false","@()","@{}","{}",'()' } | ForEach-Object {
            $Rawdata[$_.Key] = if ($_.Value -eq "true"){
                $true
            }elseif ($_.Value -eq "false") {
                $false
            }else{
                @{}
            }
        }
        Write-ActivityLog -InformationType S "Loaded successfully" -LogFile $LogFile
        return $Rawdata

    }catch{
        $Message = $_
        Write-ActivityLog -InformationType E -Text "Error: $($Message[0]) " -LogFile $LogFile
    }
}


# This function get the predefind configuration of the of strict and standard policy settings
# This will also be used of effectively change validate selection
# get predefined data set
function Get-PresetPolicyConfig {

    <#
    .SYNOPSIS
        This command gets the predefined data for standard or strict preset policy
    .DESCRIPTION
        This command is designed to get security policy configurations, either from the predefined data set of directly from the tanent.

    .PARAMETER PresetPolicyType
        This defines the data type selection. The cannot left blank The valid values are Standard and Strict

    .PARAMETER PresetPolicyDataSource
        This defines the data source selection. The valid values are PredefindPresetPolicyConfig and CurrentTenantPresetPolicyConfig. The default value is PredefindPresetPolicyConfig

    .EXAMPLE
        PS>
        Get-PresetPolicyConfig -PresetPolicyType Standard -PresetPolicyDataSource PredefindPresetPolicyConfig

        This will get the predefined standard present policy configuration from the configuration file and return data.

    #>
    param (
        # defined the preset policy type
        [Parameter(Mandatory)]
        [ValidateSet("Standard","Strict")]
        $PresetPolicyType,

        # defined the preset policy data source
        [Parameter()]
        [ValidateSet("PredefindPresetPolicyConfig","CurrentTenantPresetPolicyConfig")]
        $PresetPolicyDataSource = "PredefindPresetPolicyConfig"
    )


    try {
        switch ($PresetPolicyDataSource) {
            "PredefindPresetPolicyConfig" {
                switch ($PresetPolicyType){
                    "Standard" {
                        $pp_ati_spm = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\std_antiSpam.ps1
                        $pp_ati_mw  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\std_antiMalware.ps1
                        $pp_ati_ph  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\std_antiPhish.ps1
                        $pp_ati_sat  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\std_safeAttachment.ps1
                        $pp_ati_slk  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\std_safeLinks1.ps1
                        break
                    }
                    "Strict" {
                        $pp_ati_spm = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\str_antiSpam.ps1
                        $pp_ati_mw  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\str_antiMalware.ps1
                        $pp_ati_ph  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\str_antiPhish.ps1
                        $pp_ati_sat  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\str_safeAttachment.ps1
                        $pp_ati_slk  = Convert-ArrayToHashtable -ArrayStringData .\DefaultValues\str_safeLinks.ps1
                        break
                    }
                }
                break
            }
            "CurrentTenantPresetPolicyConfig" {
                $pp_ati_spm = Get-HostedContentFilterPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
                $pp_ati_mw = Get-MalwareFilterPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
                $pp_ati_ph = Get-AntiPhishPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
                $pp_ati_sat = Get-SafeAttachmentPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
                $pp_ati_slk =  Get-SafeLinksPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
                break
            }
        }
        return $pp_ati_spm, $pp_ati_mw, $pp_ati_ph,$pp_ati_sat,$pp_ati_slk
    }
    catch {
        $Message = $_
        Write-ActivityLog -InformationType E -Text "Error: $($Message[0]) " -LogFile $LogFile

    }
}



# Check if exhange online modue is installed
# if not instsalled, proceed to install with scope user permission else proceed to connect
# Connect to exchange online
if("ExchangeOnlineManagement" -notin (Get-InstalledModule).Name){
    Write-ActivityLog -InformationType I -Text "The ExchangeOnlineManagement module is not installed >> Proceeding to installing module to current user scope" -LogFile $LogFile
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force

    Write-ActivityLog -InformationType I -Text "ExchangeOnlineManagement module installation complted....... Connecting" -LogFile $LogFile
    Connect-ExchangeOnline -ShowBanner:$false
    Write-ActivityLog -InformationType S -Text "..........Exchange online connected successfully" -LogFile $LogFile

}else {

    $exoSessions = Get-ConnectionInformation

    if (($null -eq $exoSessions) -or ("Active" -notin $exoSessions.TokenStatus)) {
        Write-ActivityLog -InformationType I -Text "Conneting...... Sign-in with global or exchange admin account " -LogFile $LogFile
        Connect-ExchangeOnline -ShowBanner:$false
        Write-ActivityLog -InformationType S -Text ".........Exchange online connected successfully" -LogFile $LogFile
    }else {
        Write-ActivityLog -InformationType I -Text "Exchange online connected is already connected`n" -LogFile $LogFile
    }
}

#policy creation header
#DisplayHeader -text "Policy creation functions"

#Anti spam, malware, phish, safe attachment, safe link funtion
function New-PresetPolicy{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(HelpMessage="This defines the data set for antispam policy to be created")]
        [hashtable]$AntiSpam,
        [hashtable]$AntiMalware,
        [hashtable]$AntiPhish,
        [hashtable]$SafeAttachment,
        [hashtable]$SafeLink,
        [Parameter(Mandatory,HelpMessage="Specifies a test mailbox or shared that will be used to create policy rule")]
        [string]$TestSharedOrUserMailbox
    )
    # get the name of the policies for rule creation
    $PolicyNames = @{}

    if ($AntiSpam) {
        Write-ActivityLog -InformationType I -Text "Clonning Anti-Spam  $($AntiSpam.Name) and rule" -LogFile $LogFile
        $policyInfo = New-HostedContentFilterPolicy @AntiSpam
        if ($null -ne $policyInfo) {
            New-HostedContentFilterRule -Name $policyInfo.Name -HostedContentFilterPolicy $policyInfo.Name -SentTo $TestSharedOrUserMailbox | Out-Null
            $PolicyNames.Add("AntiSpam", $AntiSpam.Name)
        }
    }
    if ($AntiMalware) {
        Write-ActivityLog -InformationType I -Text "Clonning Malwar Filter  $($AntiMalware.Name) and rule" -logfile $logfile
        $policyInfo = New-MalwareFilterPolicy @AntiMalware
        if ($null -ne $policyInfo) {
            $PolicyNames.Add("AntiMalware", $policyInfo.Name)
            New-MalwareFilterRule -Name $policyInfo.Name -MalwareFilterPolicy $policyInfo.Name -SentTo $TestSharedOrUserMailbox | Out-Null
        }
    }
    if ($AntiPhish) {
        Write-ActivityLog -InformationType I -Text "Clonning Anti-Phish  $($AntiPhish.Name) and rule" -logfile $logfile
        $policyInfo = New-AntiPhishPolicy @AntiPhish
        if ($null -ne $policyInfo) {
            New-AntiPhishRule -Name $policyInfo.Name -AntiPhishPolicy $policyInfo.Name  -SentTo $TestSharedOrUserMailbox | Out-Null
            $PolicyNames.Add("AntiPhish", $policyInfo.Name)
        }
    }
    if ($SafeAttachment) {
        Write-ActivityLog -InformationType I -Text "Clonning Safe Attachment  $($SafeAttachment.Name) and rule" -logfile $logfile
        $policyInfo = New-SafeAttachmentPolicy @SafeAttachment
        if ($null -ne $policyInfo) {
            New-SafeAttachmentRule -Name $policyInfo.Name -SafeAttachmentPolicy $policyInfo.Name -SentTo $TestSharedOrUserMailbox | Out-Null
            $PolicyNames.Add("SafeAttachment", $policyInfo.Name)
        }
    }
    if ($SafeLink) {
        Write-ActivityLog -InformationType I -Text "Clonning Safe Link  $($SafeLink.Name) and rule" -logfile $logfile
        $policyInfo = New-SafeLinksPolicy @SafeLink
        if ($null -ne $policyInfo){
            New-SafeLinksRule -Name  $policyInfo.Name -SafeLinksPolicy  $policyInfo.Name -SentTo $TestSharedOrUserMailbox | Out-Null
            $PolicyNames.Add("SafeLink", $policyInfo.Name)
        }
    }

    if ($PolicyNames.Count -ne 0) {
        return $PolicyNames
    }
}

function New-SecurityPresetPolicy {
    <#
    .SYNOPSIS
        This script attempts to create a copy of the Microsoft 365 Defender preset policies.
    .DESCRIPTION
        Depending on your organization, preset security policies provide many of the protection features that are available
        in Exchange Online Protection (EOP) and Microsoft Defender for Office 365.
        The script give generate copy of all policies that are releate to Standard and Strict present policies

        The policy on clone the existing policy and does not take care of any future change make back Microsoft backend team.
        Admins are responsible to manually update the changes that microsoft makes to preset on the clonned security preset policies

    .PARAMETER PresetPolicyType
        Specifies the type of the security present policy to create, the valid values "Standard","Strict","StandardStrictPolicy"
    .PARAMETER SecurityPresetPolicy
        "Selection the option needed for policy creation, that antispam, malware, antiphish, safe links and safe attachment, you can select to create all policies or specifics
        adn the valid values are AntiSpamPolicy, AntiPhishPolicy, MalwarePolicy, SafeAttachmentPolicy,SafeLinkPolicy,AllPresetPolicy
    .PARAMETER PresetPolicyDataSource
        This will specify that data source that will be used for the preset policy creation, the valid values are PredefindPresetPolicyConfig and CurrentTenantPresetPolicyConfig
        The default value is PredefindPresetPolicyConfig
    .PARAMETER TestSharedOrUserMailbox
        Specifies a test mailbox or shared that will be used to create policy rule. if the provided object is not a mailbox or shared mailbox,
        A new shared mailbox be automaticall created and used for the policy rule creation.

    .EXAMPLE
        PS>
        New-SecurityPresetPolicy -PresetPolicyType Standard -SecurityPresetPolicy AntiSpamPolicy -TestSharedOrUserMailbox demo@user.com

        This will create a Anti-spam standard present policy and apply to the demo account.

    .EXAMPLE
        PS>
        New-SecurityPresetPolicy -PresetPolicyType Standard -SecurityPresetPolicy AntiSpamPolicy -PresetPolicyDataSource PredefindPresetPolicyConfig -TestSharedOrUserMailbox demo@user.com

        This will create a Anti-spam standard present policy and apply to the demo account. This is the same as example 1 because PresetPolicyDataSource has PredefindPresetPolicyConfig as default.

    .EXAMPLE
        PS>
        New-SecurityPresetPolicy -PresetPolicyType Standard -SecurityPresetPolicy AllPresetPolicy -TestSharedOrUserMailbox demo@user.com

        This will create a Anti-spam, Anti-Phish, Malware, SafeAttachment and SafeLink standard present policy and apply to the demo account.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(

        # Policy type selection
        [Parameter(HelpMessage="Standard: This will generate standard security preset policies `nStrictPolicy: This will generate strict security preset policies `nStandardStrictPolicy: This will generate both standard and strict preset policies")]
        [ValidateSet("Standard","Strict","StandardAndStrict")]
        $PresetPolicyType,

        # # this provides the type of policies that can be create depending on what is selected
        [Parameter(HelpMessage="Selection the option needed for policy creation, that antispam, malware, antiphish, safe links and safe attachment, you can select to create all policies or specific")]
        [ValidateSet("AntiSpamPolicy","AntiPhishPolicy","MalwarePolicy","SafeAttachmentPolicy","SafeLinkPolicy","AllPresetPolicy")]
        $SecurityPresetPolicy,

        # defined the preset policy data source
        [Parameter()]
        [ValidateSet("PredefindPresetPolicyConfig","CurrentTenantPresetPolicyConfig")]
        $PresetPolicyDataSource = "PredefindPresetPolicyConfig",

        # TestSharedOrUserMailbox
        [Parameter(Mandatory,HelpMessage="Specifies a test mailbox or shared that will be used to create policy rule")]
        [string]
        $TestSharedOrUserMailbox

    )

    try {

        #validate TestSharedOrUserMailbox
        try {

            $ValidateUser = Get-Recipient $TestSharedOrUserMailbox -ErrorAction SilentlyContinue
            if (($ValidateUser.RecipientTypeDetails -notin "SharedMailbox","UserMailbbox") -or ($null -eq $ValidateUser)) {
                Write-ActivityLog -InformationType I -Text "The $($TestSharedOrUserMailbox)  account does not exist or not user/shared mailbox....... Proceeting to create a new shared mailbox for test purposes" -LogFile $LogFile
                $TestSharedOrUserMailbox = (New-Mailbox  $($TestSharedOrUserMailbox)+"-"+$(Get-Date).TimeOfDay.Ticks -Shared).PrimarySMTPAddress
            }else {
                Write-ActivityLog -InformationType I -Text "The $($TestSharedOrUserMailbox) account provided is valid" -LogFile $LogFile
            }
        }
        catch {
            $Message = $_
            Write-ActivityLog -InformationType E -Text "Error: $($Message[0]) " -LogFile $LogFile
        }

        if ($PSBoundParameters["PresetPolicyType"] -in "Standard","Strict") {

            #Preset policy data set
            $pp_ati_spm, $pp_ati_mw, $pp_ati_ph, $pp_ati_sat, $pp_ati_slk = if($PresetPolicyType -eq "Standard"){
                Get-PresetPolicyConfig -PresetPolicyType $PresetPolicyType -PresetPolicyDataSource $PresetPolicyDataSource
            }else{
                Get-PresetPolicyConfig -PresetPolicyType $PresetPolicyType -PresetPolicyDataSource $PresetPolicyDataSource
            }

            switch ($SecurityPresetPolicy) {
                "AllPresetPolicy" {
                    New-PresetPolicy -AntiSpam $pp_ati_spm -AntiMalware $pp_ati_mw -AntiPhish $pp_ati_ph -SafeAttachment $pp_ati_sat -SafeLink $pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "AntiSpamPolicy" {
                    New-PresetPolicy -AntiSpam $pp_ati_spm -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "MalwarePolicy" {
                    New-PresetPolicy -AntiMalware $pp_ati_mw -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "AntiPhishPolicy" {
                    New-PresetPolicy -AntiPhish $pp_ati_ph -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "SafeAttachmentPolicy" {
                    New-PresetPolicy -SafeAttachment $pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "SafeLinkPolicy" {
                    New-PresetPolicy -SafeLink $pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
            }
        }else {
            # This section will create both standard and strict preset policy depending on the feature selected
            $std_pp_ati_spm, $std_pp_ati_mw, $std_pp_ati_ph, $std_pp_ati_sat, $std_pp_ati_slk = Get-PresetPolicyConfig -PresetPolicyType Standard -PresetPolicyDataSource $PresetPolicyDataSource
            $str_pp_ati_spm, $str_pp_ati_mw, $str_pp_ati_ph, $str_pp_ati_sat, $str_pp_ati_slk = Get-PresetPolicyConfig -PresetPolicyType Strict -PresetPolicyDataSource $PresetPolicyDataSource

            switch ($SecurityPresetPolicy) {
                "AllPresetPolicy" {
                    New-PresetPolicy -AntiSpam $std_pp_ati_spm -AntiMalware $std_pp_ati_mw -AntiPhish $std_pp_ati_ph -SafeAttachment $std_pp_ati_sat -SafeLink $std_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -AntiSpam $str_pp_ati_spm -AntiMalware $str_pp_ati_mw -AntiPhish $str_pp_ati_ph -SafeAttachment $str_pp_ati_sat -SafeLink $str_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "AntiSpamPolicy" {
                    New-PresetPolicy -AntiSpam $std_pp_ati_spm -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -AntiSpam $str_pp_ati_spm -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "MalwarePolicy" {
                    New-PresetPolicy -AntiMalware $std_pp_ati_mw -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -AntiMalware $str_pp_ati_mw -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "AntiPhishPolicy" {
                    New-PresetPolicy -AntiPhish $std_pp_ati_ph -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -AntiPhish $str_pp_ati_ph -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "SafeAttachmentPolicy" {
                    New-PresetPolicy -SafeAttachment $std_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -SafeAttachment $str_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
                "SafeLinkPolicy" {
                    New-PresetPolicy -SafeLink $std_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    New-PresetPolicy -SafeLink $str_pp_ati_slk -TestSharedOrUserMailbox $TestSharedOrUserMailbox
                    break
                }
            }

        }
    }
    catch {
        $Message = $_
        Write-ActivityLog -InformationType E -Text "Error: $($Message[0]) " -LogFile $LogFile

    }


}

