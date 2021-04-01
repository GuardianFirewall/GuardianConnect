//
//  Shared.h
//  Guardian
//
//  Created by Kevin Bradley on 10/13/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#ifndef Shared_h
#define Shared_h

//Logging Macros

#define GRDLog(x, ...) NSLog(@"%s(L%d) " x, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define DLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);
#define LOG_SELF        NSLog(@"%@ %@", self, NSStringFromSelector(_cmd))
#define DLOG_SELF DLog(@"%@ %@", self, NSStringFromSelector(_cmd))

#define kGRDServerUpdatedNotification @"GRDServerUpdatedNotification"
#define kGRDLocationUpdatedNotification @"GRDLocationUpdatedNotification"
#define kGRDSubscriptionUpdatedNotification @"GRDSubscriptionUpdatedNotification"

// Define below both to 0 to make guardian specific code inactive
#define GUARDIAN_INTERNAL 1
#define IS_GUARDIAN_APP 0

#pragma mark - Misc

#define kAppNeedsSelfRepair             @"guardianNeedsSelfRepair"

#pragma mark - Housekeeping / Region / Timezone

#define kGuardianNetworkHealthStatusNotification @"networkHealthStatusNotification"
#define kGuardianSuccessfulSubscription @"successfullySubscribedToGuardian"

static NSString * const kVPNHadNetworkHealthDisconnect = @"vpnHadNetworkHealthDisconnect";
static NSString * const kGRDHostnameOverride = @"APIHostname-Override";
static NSString * const kGRDEAPSharedHostname = @"SharedAPIHostname";
static NSString * const kGRDVPNHostLocation = @"kGRDVPNHostLocation";
static NSString * const kGRDIncludesAllNetworks = @"kGRDIncludesAllNetworks";
static NSString * const kGRDExcludeLocalNetworks = @"kGRDExcludeLocalNetworks";
static NSString * const kGRDWifiAssistEnableFallback = @"kGRDWifiAssistEnableFallback";
static NSString * const kGRDRefreshProxySettings = @"kGRDRefreshProxySettings";
static NSString * const kGRDTunnelEnabled = @"kGRDTunnelEnabled";

static NSString * const kGuardianFauxTimeZone = @"faux-timezone";
static NSString * const kGuardianFauxTimeZonePretty = @"faux-timezone-pretty";
static NSString * const kGuardianUseFauxTimeZone = @"use-faux-timezone";
static NSString * const kKnownHousekeepingTimeZonesForRegions = @"kKnownHousekeepingTimeZonesForRegions";
static NSString * const housekeepingTimezonesTimestamp = @"housekeepingTimezonesTimestamp";
static NSString * const kGuardianAllRegions = @"kGRDAllRegions";
static NSString * const kGuardianAllRegionsTimeStamp = @"kGRDAllRegionsTimeStamp";


#pragma mark - Subscription types + related
static NSString * const kGuardianSubscriptionTypeEssentials             = @"grd_type_essentials";
static NSString * const kGuardianSubscriptionDayPass                    = @"grd_day_pass";
static NSString * const kGuardianSubscriptionDayPassAlt                 = @"grd_day_pass_alt";
static NSString * const kGuardianSubscriptionGiftedDayPass              = @"grd_gifted_day_pass";
static NSString * const kGuardianSubscriptionCustomDayPass              = @"custom_day_pass";
static NSString * const kGuardianSubscriptionMonthly                    = @"grd_monthly";
static NSString * const kGuardianSubscriptionThreeMonths                = @"grd_three_months";
static NSString * const kGuardianSubscriptionAnnual                     = @"grd_annual";
static NSString * const kGuardianSubscriptionTypeProfessionalIAP        = @"grd_pro";
static NSString * const kGuardianSubscriptionTypeCustomDayPass          = @"grd_custom_day_pass";
static NSString * const kGuardianSubscriptionTypeIntroductory           = @"grd_day_pass_introductory";

static NSString * const kGuardianFreeTrial3Days                         = @"grd_trial_3_days";
static NSString * const kGuardianExtendedTrial30Days                    = @"grd_extended_trial_30_days";
static NSString * const kGuardianTrialBalanceDayPasses                  = @"grd_trial_balance_day_passes";
static NSString * const kGuardianSubscriptionFreeTrial                  = @"free_trial";

static NSString * const kGuardianSubscriptionTypeVisionary              = @"grd_visionary";
static NSString * const kGuardianSubscriptionTypeProfessionalMonthly    = @"grd_pro_monthly";
static NSString * const kGuardianSubscriptionTypeProfessionalYearly     = @"grd_pro_yearly";
static NSString * const kGuardianSubscriptionTypeProfessionalBrave      = @"bravevpn.yearly-pro";

static NSString * const kGuardianFreeTrialPeTokenSet                    = @"kGRDFreeTrialPETokenSet";
static NSString * const kGuardianDayPassExpirationDate                  = @"GuardianDayPassExpirationDate";
static NSString * const kGuardianPETokenExpirationDate                  = @"kGuardianPETokenExpirationDate";


//newly added

#define kIsPremiumUser                  @"userHasPaidSubscription"
#define kSubscriptionPlanTypeStr @"subscriptionPlanType"


#endif /* Shared_h */
