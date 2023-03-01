//
//  GRDDNSHelper.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 15.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#import <GuardianConnect/GRDKeychain.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGRDKeychainStr_DNSFRoamingClientId = @"dnsf-roaming-client-id";
static NSString * const kDNSFDefaultDOHHostname 			= @"doh.dnsfilter.com";

typedef NS_ENUM(NSInteger, GRDDNSSettingsType) {
	DNSSettingsTypeUnknown = -1,
	DNSSettingsTypeDOH,
	DNSSettingsTypeDOT
};

API_AVAILABLE(macos(11.0), ios(14.0))
@interface GRDDNSHelper : NSObject


/// Public readonly access to the app's [NEDSNSettingsManager sharedInstance] reference.
/// This property should be non-nil after the first call to [GRDDNSHelper sharedInstance]
@property (readonly) NEDNSSettingsManager * _Nullable dnsSettingManager;

/// The default on demand rules used by GRDDNSHelper if 'customOnDemandRules' is not set
///
/// By default this property is set to route all DNS queries on all interfaces to the defined DoH server. This is the recommended configuration to ensure that all traffic is captures and filtered
@property (readonly) NSArray<NEOnDemandRule *> *defaultOnDemandRules;

/// Provides the ability to set custom on demand rules to filter by interface, WiFi name or provides the ability to set a probeURL either
///
/// It is not recommended to set custom on demand rules and rather rely on the provided default on demand rules which route all DNS queries on all interfaces to the defined DoH server to ensure property filtering and protection
@property NSArray<NEOnDemandRule *> *customOnDemandRules;

/// Gives the ability to set a custom DoH hostname for custom infrastructure configurations
///
/// The default value here is 'doh.dnsftiler.com'. Please only provide the hostname as a custom value without the protocol. By default GRDDNSHelper enforces 'https://' as the default protocol
@property NSString *customDNSFHostname;

/// String used as the value shown to the user in the Settings application on iOS or System Preferences on macOS
///
/// This string should be formatted in a user presetnable way and should be kept to less than 20 characters if possible.
/// This value cannot be nil and has to be set in order to successfully set a DNS settings configuration
@property NSString *localizedDNSConfigurationDescription;

/// The (readonly) DNSFilter roaming client id used by the DNS settings configuration
///
/// If no DNS settings configuration is set, this property will be nil.
/// It is stored and retrieved securely from the system's keychain service and removed upon calling 'removeDNSSettingsConfiguration'
@property (readonly) NSString * _Nullable dnsfRoamingClientId;



/// The shared instance of GRDDNSHelper
///
/// The class' instance methods should only be accessed by calling [GRDDNSHelper sharedInstance] first. This ensure that the dnsSettingsManager property is populated and default values have been set
+ (instancetype)sharedInstance;

/// A convenience method to quickly load the set DNS settings configuration to read properties of the configuration
/// This mehtod will call [GRDDNSHelper sharedInstance] once to ensure that the default values are set.
/// This also ensures that the DNS settings configuration properties can afterwards be accessed through the shared instance 'dnsSettingsManager' property if so desired. In case no DNS settings configuration is set yet the completion block will return no error message, but the 'dnsSettingsManager' property should be set to nil
/// - Parameter completion: completion block containing an error message string. If no error occured during loading of the DNS settings configuration this will be nil
+ (void)loadDNSSettingsConfigurationWithCompletion:(void (^)(NSError * _Nullable errorMessage))completion;

/// Convenience method to save a DNS setting configuration with framework provided defaults or by using the provided proerties, as well as the method parameters.
/// Currently only the DNSSettingsTypeDOH is supported
/// - Parameters:
///   - dnsSettingsType: Enum type to quickly determine how the DNS settings configuration should be applied
///   - roamingClientId: DNSFilter roaming client id used to route the DNS queries properly and apply the correct policies for the device
///   - completion: completion block containing a error message string in case the DNS settings configuration can either not be saved or not be loaded
- (void)setDNSSettingsConfigurationWithType:(GRDDNSSettingsType)dnsSettingsType roamingClientId:(NSString * _Nonnull)roamingClientId andCompletion:(void (^)(NSError * _Nullable errorMessage))completion;

/// Convenience function to remove the DNS settings configuration from the device.
///
/// ! Attention: This method does not expose the underlying error message in case of a failure to remove the DNS settings configuration. It is meant to be a simple and fast way to remove the DNS settings configuration without any further checks.
- (void)removeDNSSettingsConfiguration;

@end

NS_ASSUME_NONNULL_END
