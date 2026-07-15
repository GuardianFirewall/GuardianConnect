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

# pragma mark - API Features

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

static NSString * const kGRDAPIAuthTokenHTTPHeader 						= @"grd-api-auth-token";

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
static NSString * const kGRDClientRulesList								= @"kGRDClientRulesList";

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

// Used to hard to code IAP receipts and create Subscriber Credentials
static NSString * const kGuardianEncodedAppStoreReceipt 						= @"kGuardianEncodedAppStoreReceipt";
static NSString * const kGuardianPreferredSubscriberCredentialValidationMethod 	= @"kGuardianPreferredSubscriberCredentialValidationMethod";

//moved to make framework friendly
static NSString * const kIsPremiumUser                                  = @"userHasPaidSubscription";
static NSString * const kGRDSubscriptionUpdatedNotification				= @"GRDSubscriptionUpdatedNotification";


#pragma mark - Region Precision
static NSString * const kGRDPreferredRegionPrecision 		= @"kGRDPreferredRegionPrecision";
static NSString * const kGRDRegionPrecisionDefault 			= @"default";
static NSString * const kGRDRegionPrecisionCity 			= @"city";
static NSString * const kGRDRegionPrecisionCountry 			= @"country";
static NSString * const kGRDRegionPrecisionCityByCountry	= @"city-by-country";
static NSString * const kGRDPreferredRegionPrecisionCustom	= @"kGRDPreferredRegionPrecisionCustom";


#pragma mark - SRP Region States
static NSString * const kGRDRegionSmartRoutingProxyNone = @"none";
static NSString * const kGRDRegionSmartRoutingProxySome = @"some";
static NSString * const kGRDRegionSmartRoutingProxyAll 	= @"all";


# pragma mark - Trusted Networks
static NSString * const kGRDDisconnectOnEthernet		= @"kGRDDisconnectOnEthernet";
static NSString * const kGRDDisconnectOnTrustedNetworks	= @"kGRDDisconnectOnTrustedNetworks";
static NSString * const kGRDTrustedNetworksArray		= @"kGRDTrustedNetworksArray";

static NSString * const kGRDKillSwitchEnabled       	= @"kGRDKillSwitchEnabled";

static NSString * const kGRDDeviceFilterConfigBlocklist = @"kGRDDeviceFilterConfigBlocklist";


#pragma mark - Stealth Mode (GRD-1391)
// Stealth Mode connects the VPN by direct IP instead of FQDN so the connection can
// be established on hostile networks where DNS for the SGW hostname is poisoned
// (e.g. resolves to 0.0.0.0). It is OFF by default; when off, all connect-path logic
// behaves exactly as before. The FQDN (credential.hostname) is never overwritten;
// only the dial target is substituted, and only when a cached IP is available.
// NOTE (GRD-1391 future work): the IP cache is IPv4-only. IPv6 / dual-stack is not
// yet supported; v6-only or v4-less nodes fall back to connecting by FQDN.
static NSString * const kGRDStealthModeEnabled			= @"kGRDStealthModeEnabled";
static NSString * const kGRDStealthSGWIPCache			= @"kGRDStealthSGWIPCache";		// NSDictionary<hostname (NSString), ipv4 (NSString)>
static NSString * const kGRDStealthSGWIPCacheDate		= @"kGRDStealthSGWIPCacheDate";	// NSDate of last successful refresh

NS_ASSUME_NONNULL_END
#endif /* Shared_h */
