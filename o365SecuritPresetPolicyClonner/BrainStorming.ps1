# Getting the current default Strict and standard policy
# The policy retrival will depend on the select option by user
# if user selects Predefined or defult, you must use either strict or standard,StrictPredefined and StandardPredefined

# Check if the $pp_ati_mw, $pp_ati_ph and $pp_ati_spm are NULL
# If standard or strict is selected and the variables are null because the policy was never enabled on the tenant.
# then, the predefind data will be loaded and and policy will be created based on that.
# Strict will be substituted by StrictPredefined and Standard will be replaced by StandardPredefined calling the Get-PredefinedData function

function Get-DefaultPresetPolicy {

    param(
        [Parameter()]
        [ValidateSet("Standard","Strict")]
        $PresetPolicyType = "Standard"
    )

    # locad the predefind data set, this will be used to replace any policy that returns null
    $PredefinedPresetPolicySettings = if($PresetPolicyType -eq "Standard"){Get-StandardPredefinedPolicy}else{Get-StrictPredefinedPolicy}

    #getting the tenant value settings
    $pp_ati_spm = Get-HostedContentFilterPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
    $pp_ati_mw = Get-MalwareFilterPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
    $pp_ati_ph = Get-AntiPhishPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
    $pp_ati_sat = Get-SafeAttachmentPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType
    $pp_ati_slk =  Get-SafeLinksPolicy | Where-Object -Property RecommendedPolicyType -eq -Value $PresetPolicyType

    #checking and setting the values to the predefine value of the virables are null
    if ($null -eq $pp_ati_spm) {
        $pp_ati_spm = $PredefinedPresetPolicySettings[0]
    }

    if ($null -eq $pp_ati_mw) {
        $pp_ati_mw  = $PredefinedPresetPolicySettings[1]
    }

    if ($null -eq $pp_ati_ph) {
        $pp_ati_ph  = $PredefinedPresetPolicySettings[2]
    }

    if ($null -eq $pp_ati_sat) {
        $pp_ati_sat  = $PredefinedPresetPolicySettings[3]
    }

    if ($null -eq $pp_ati_slk) {
        $pp_ati_slk  = $PredefinedPresetPolicySettings[4]
    }

    return $pp_ati_spm, $pp_ati_mw, $pp_ati_ph,$pp_ati_sat,$pp_ati_slk

}
