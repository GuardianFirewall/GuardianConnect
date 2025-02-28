//
//  Shared.h
//  Guardian
//
//  Created by Kevin Bradley on 10/13/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef Shared_h
#define Shared_h

NS_ASSUME_NONNULL_BEGIN

typedef void (^StandardBlock)(BOOL success, NSString * _Nullable errorMessage);
typedef void (^ResponseBlock)(NSDictionary * _Nullable response, NSString * _Nullable errorMessage, BOOL success);


typedef NS_ENUM(NSInteger, GRDServerFeatureEnvironment) {
	ServerFeatureEnvironmentProduction = 1,
	ServerFeatureEnvironmentInternal,
	ServerFeatureEnvironmentDevelopment,
	ServerFeatureEnvironmentDualStack,
	ServerFeatureEnvironmentUnstable
};

//
// Note from CJ 2024-01-18:
// I have moved this enum in the shared framework header in order to resolve
// the problem of circular imports being very difficult to get right
// between various classes with regards to enums specifically
// ---
/// Validation Method used to obtain a signed JWT from housekeeping
typedef NS_ENUM(NSInteger, GRDHousekeepingValidationMethod) {
	ValidationMethodInvalid = -1,
	ValidationMethodAppStoreReceipt,
	ValidationMethodPEToken,
	ValidationMethodCustom
};


/// Public production Connect API environment
static NSString * const kConnectAPIHostname 							= @"connect-api.guardianapp.com";

static NSString * const kGRDHousekeepingAPIHostname						= @"kGRDHousekeepingAPIHostname";
static NSString * const kGRDConnectAPIHostname							= @"kGRDConnectAPIHostname";
static NSString * const kGRDConnectPublishableKey						= @"kGRDConnectPublishableKey";

// The value below and the kGRDConnectAPIHostname may seem redundant
// but duplicated values are retained in order to allow for the scenario
// in which a certain Connect API env needs to be hit while no PET exists yet
static NSString * const kGuardianPETConnectAPIEnv                  		= @"kGuardianPETConnectAPIEnv";
static NSString * const kGuardianPETokenExpirationDate                  = @"kGuardianPETokenExpirationDate";

static NSString * const kGuardianSuccessfulSubscription                 = @"successfullySubscribedToGuardian";

#pragma mark - SGW Features
static NSString * const kGRDBetaCapablePreferred 						= @"kGRDBetaCapablePreferred";
static NSString * const kGRDServerFeatureEnvironment 					= @"kGRDServerFeatureEnvironment";


static NSString * const kGRDVPNHostLocation                             = @"kGRDVPNHostLocation";
static NSString * const kGRDIncludesAllNetworks                         = @"kGRDIncludesAllNetworks";
static NSString * const kGRDWifiAssistEnableFallback                    = @"kGRDWifiAssistEnableFallback";
static NSString * const kGRDSmartRountingProxyEnabled					= @"kGRDSmartRountingProxyEnabled";
static NSString * const kGRDBlocklistsEnabled 							= @"kGRDBlocklistsEnabled";
static NSString * const kGRDBlocklistGroups							 	= @"kGRDBlocklistGroups";
static NSString * const kGuardianTransportProtocol						= @"kGuardianTransportProtocol";

static NSString * const kGRDWGDevicePublicKey                           = @"wg-device-public-key";
static NSString * const kGRDWGDevicePrivateKey							= @"wg-device-private-key";
static NSString * const kGRDWGServerPublicKey                           = @"server-public-key";
static NSString * const kGRDWGIPv4Address                               = @"mapped-ipv4-address";
static NSString * const kGRDWGIPv6Address                               = @"mapped-ipv6-address";
static NSString * const kGRDClientId                               		= @"client-id";

static NSString * const kGuardianRegionOverride							= @"kGuardianRegionOverride";
static NSString * const kGuardianSubscriptionExpiresDate                = @"subscriptionExpiresDate";

/// Used to determine whether the device has changed regions in automatic
/// routing mode and the user may want to reconsider reconnecting to a different
/// server for a faster connection
static NSString * const kGRDLastKnownAutomaticRegion	 				= @"kGRDLastKnownAutomaticRegion";


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
// "grd_teams" is an umbrealla description. Should never be used in production since it does not accurately describe the subscription length etc.
static NSString * const kGuardianSubscriptionTypeTeams 					= @"grd_teams";
static NSString * const kGuardianSubscriptionTypeTeamsAnnual			= @"grd_teams_annual";

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

static NSString * const kGuardianSubscriptionProductIds                 = @"kGuardianSubscriptionProductIds";

// Used to hard to code IAP receipts and create Subscriber Credentials
static NSString * const kGuardianEncodedAppStoreReceipt 						= @"kGuardianEncodedAppStoreReceipt";
static NSString * const kGuardianPreferredSubscriberCredentialValidationMethod 	= @"kGuardianPreferredSubscriberCredentialValidationMethod";

//moved to make framework friendly
static NSString * const kIsPremiumUser                                  = @"userHasPaidSubscription";
static NSString * const kSubscriptionPlanTypeStr                        = @"subscriptionPlanType";

typedef NS_ENUM(NSInteger, GRDPlanDetailType) {
    GRDPlanDetailTypeFree = 0,
    GRDPlanDetailTypeEssentials,
    GRDPlanDetailTypeProfessional
};

#define kGRDServerUpdatedNotification @"GRDServerUpdatedNotification"
#define kGRDLocationUpdatedNotification @"GRDLocationUpdatedNotification"
#define kGRDSubscriptionUpdatedNotification @"GRDSubscriptionUpdatedNotification"


#pragma mark - Region precision constant
static NSString * const kGRDPreferredRegionPrecision 		= @"kGRDPreferredRegionPrecision";
static NSString * const kGRDRegionPrecisionDefault 			= @"default";
static NSString * const kGRDRegionPrecisionCity 			= @"city";
static NSString * const kGRDRegionPrecisionCountry 			= @"country";
static NSString * const kGRDRegionPrecisionCityByCountry	= @"city-by-country";
static NSString * const kGRDPreferredRegionPrecisionCustom	= @"kGRDPreferredRegionPrecisionCustom";


# pragma mark - Trusted Network constants
static NSString * const kGRDDisconnectOnTrustedNetworks	= @"kGRDDisconnectOnTrustedNetworks";
static NSString * const kGRDTrustedNetworksArray		= @"kGRDTrustedNetworksArray";

static NSString * const kGRDKillSwitchEnabled       	= @"kGRDKillSwitchEnabled";

static NSString * const kGRDTrialExpirationInterval =          @"kGRDTrialExpirationInterval";
static NSString * const kGRDFreeTrialExpired =                 @"kGRDFreeTrialExpired";



static NSString * const kGRDDeviceFilterConfigBlocklist = @"kGRDDeviceFilterConfigBlocklist";

NS_ASSUME_NONNULL_END
#endif /* Shared_h */
