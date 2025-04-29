ImpersonationProtectionState                  = Automatic
EnableTargetedUserProtection                  = True
EnableMailboxIntelligenceProtection           = True
EnableTargetedDomainsProtection               = True
EnableOrganizationDomainsProtection           = True
EnableMailboxIntelligence                     = True
EnableFirstContactSafetyTips                  = True
EnableSimilarUsersSafetyTips                  = True
EnableSimilarDomainsSafetyTips                = True
EnableUnusualCharactersSafetyTips             = True
TargetedUserProtectionAction                  = Quarantine
TargetedUserQuarantineTag                     = DefaultFullAccessWithNotificationPolicy
MailboxIntelligenceProtectionAction           = MoveToJmf
MailboxIntelligenceQuarantineTag              = DefaultFullAccessPolicy
TargetedDomainProtectionAction                = Quarantine
TargetedDomainQuarantineTag                   = DefaultFullAccessWithNotificationPolicy
AuthenticationFailAction                      = MoveToJmf
SpoofQuarantineTag                            = DefaultFullAccessPolicy
EnableSpoofIntelligence                       = True
EnableViaTag                                  = True
EnableUnauthenticatedSender                   = True
HonorDmarcPolicy                              = True
DmarcRejectAction                             = Reject
DmarcQuarantineAction                         = Quarantine
PhishThresholdLevel                           = 3
TargetedUsersToProtect                        = @{}
TargetedUserActionRecipients                  = @{}
MailboxIntelligenceProtectionActionRecipients = @{}
TargetedDomainsToProtect                      = @{}
TargetedDomainActionRecipients                = @{}
ExcludedDomains                               = @{}
ExcludedSenders                               = @{}
Name                                          = Custom Standard Preset Security Policy



