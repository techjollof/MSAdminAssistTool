
Remove-module SecurityPresetPolicyClonner -ErrorAction SilentlyContinue

#text for lenght
$textLenght = 135
$title = @'

    
#######################################################################################################################################
#                                                                                                                                     #
#                        Preset security policies in EOP and Microsoft Defender for Office 365                                        #
#                                                                                                                                     #
#######################################################################################################################################

    This script attempts to create a copy of the Microsoft 365 Defender preset policies

    Depending on your organization, preset security policies provide many of the protection features that are available 
    in Exchange Online Protection (EOP) and Microsoft Defender for Office 365.

        Preset security policies allow you to apply protection features to users based on our recommended settings. 
        Unlike custom policies that are infinitely configurable, virtually all of the settings in preset security policies 
        aren't configurable, and are based on our observations in the datacenters. The settings in preset security policies
        provide a balance between keeping harmful content away from users while avoiding unnecessary disruptions.

    The script give generate copy of all policies that are releate to Standard and Strict present policies

    The policy on clone the existing policy and does not take care of any future change make back Microsoft backend team.
    Admins are responsible to manually update the changes that microsoft makes to preset on the clonned security preset policies

    This is basically a custom policy but completely using the existing preset policies at the time of script creation

    The scritpt can address few things

        *   Help apply further customization to preset that cannot be done default
        *   If the present not yet enabled on the tenant, the custom preset policeis will be created setting at the creation of ths script
        *   There are some configurable and non configurable paramters below is the list some of the relevant or notables
        *   Unchangeable Paramters: 
                EnableSuspiciousSafetyTip:feature cannot be MODIFIED an this is by design, this means that the "Strict Preset 
                Policy" value for EnableSuspiciousSafetyTip is True but cannot be transferred to the "Custom Strict Preset Policy" 
                because it cannot be changed For more information: 
                    https://learn.microsoft.com/en-us/powershell/module/exchange/get-antiphishpolicy?view=exchange-ps#-advanced

                ZapEnabled: This paramter by default is set to TRUE for both standard and strict but this is not configurable for 
                the HostedContentFilterPolicy(Anti-spam inbound policy) becuause is basicallt inherided from MalwareFilterPolicy. 

        *   Configuratable Paramters
                Malware Policy
                InternalSenderAdminAddress / ExternalSenderAdminAddress / EnableExternalSenderAdminNotifications: This paramter
                can be configured but is not configure on the both strict and standard policy. If you want use use it, the you 
                can configure it later by using the portal or Set-MalwareFilterPolicy <Policy Name>. For more information you
                can refer to the link to know about the applicable situation:
                    https://learn.microsoft.com/en-us/powershell/module/exchange/new-malwarefilterpolicy?view=exchange-ps
                
'@

$warrantStament =@"

###############################################                   WARRANTY               ############################################

    THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
    BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
    OF OR IN CONNECTION WITH THE SCRIPT OR THE USE OR OTHER DEALINGS IN THE SCRIPT.


"@

$CallableFunctions = @"

##################################                List of functions thatc can be use               ##########################################

    New-PresetPolicy          | This one can be used to create new policy such as Anti-Spam, Anti-Phish, Malware, SafeAttachment, SafeLink
    Get-PresetPolicyConfig    | Get and inspect the policy configuration dataset, which can or will be use to create policy
    New-SecurityPresetPolicy  | Main function for policy and correspointing rule creation


    Use get-help <Command-Name> to know more about the command and paramters accepted by the command

"@



# define Error handling
# note: do not change these values
$global:ErrorActionPreference = "Stop"
if($verbose){ $global:VerbosePreference = "Continue" }


#Importing common functions
. $PSScriptRoot\CommonFunctions.ps1

#Write function formatter



DisplayHelp -text $title
DisplayHelp -text $warrantStament #-color Yellow

$UsageAgreement = $(Write-Host "Do you AGREE to the terms and conditons [Yes(Y)/No(N)? : " -noNewline;Read-Host)

Write-ActivityLog -InformationType I -Text "User was presented with license agreement conditons [Yes(Y)/No(N)" -LogFile $LogFile

if($UsageAgreement -in "Yes,Y".ToLower().Split(",")){

    Write-ActivityLog -InformationType I -Text "The license agreement conditons was accepted, preceeding to import the needed functionss" -LogFile $LogFile
    DisplayHelp -text $CallableFunctions
    Import-module ".\SecurityPresetPolicyClonnerFunctions.psm1"

    Write-ActivityLog -InformationType S -Text "Function import successful" -LogFile $LogFile

}else {
    
    Remove-Module  SecurityPresetPolicyClonnerFunctions -ErrorAction SilentlyContinue
    Remove-Module  SecurityPresetPolicyClonnerProgram -ErrorAction SilentlyContinue 
    Write-ActivityLog -InformationType I -Text "The program has ended because usage terms were declined and no command was inported!!!" -LogFile $LogFile
    Write-ActivityLog -InformationTyp S -Text "Success" -LogFile $LogFile
    
}

