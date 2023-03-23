//
//  GRDDeviceFilterConfigBlocklist.h
//  GuardianCore
//
//  Created by Constantin Jacob on 17.11.21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDGatewayAPI.h>
#import <GuardianConnect/GRDCredentialManager.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, DeviceFilterConfigBlocklist) {
	DeviceFilterConfigBlocklistDisableFirewall 	= (1 << 0),
	DeviceFilterConfigBlocklistBlockAds 		= (1 << 1),
	DeviceFilterConfigBlocklistBlockPhishing 	= (1 << 2),
	DeviceFilterConfigBlocklistMax 				= (1 << 3)
};

@interface GRDDeviceFilterConfigBlocklist : NSObject

/// The internal blocklist config state
@property (nonatomic, readonly) NSUInteger bitwiseConfig;

/// Convenience method to obtain the persistent reference of the device's blocklist filter config
///
/// This method should be used as the entry path for further use of this class
+ (GRDDeviceFilterConfigBlocklist *)currentBlocklistConfig;

/// Convenience method to store a device filter config state in NSUserDefaults
- (void)setConfig:(DeviceFilterConfigBlocklist)config enabled:(BOOL)enabled;

/// Returns YES/true if the DeviceFilterConfigBlocklist is set
/// - Parameter config: the DeviceFilterConfigBlocklist to check
- (BOOL)hasConfig:(DeviceFilterConfigBlocklist)config;

/// Return yes if any of the values in the API portable dictionary are set to yes
/// Useful to determine whether or not the users preferences need to be synced to the server
- (BOOL)blocklistEnabled;

/// Returns a NSDictionary containing all currently known device filter configs states
/// already formatted in a way that the VPN node API will understand the data
- (NSDictionary *)apiPortableBlocklist;

/// Returns the blocklist config item's formatted title, or in the case of multiple being set a string with all titles separated by ' | '
/// - Parameter config: the blocklist config for which the title(s) should be returned
- (NSString *)titleForDeviceFilterConfigBlocklist:(DeviceFilterConfigBlocklist)config;

/// Returns the properly formatted API key for a given DeviceFilterConfigBlocklist
///
/// If the provided config does not matcha a single config nil will be returned
/// - Parameter config: the blocklist config for which the api key should be returned
- (NSString * _Nullable)apiKeyForDeviceFilterConfigBlocklist:(DeviceFilterConfigBlocklist)config;


# pragma mark - API Wrapper

/// Convenience function to sync the device's current blocklist config with the VPN node. If no VPN node is set or no main credentials are present on the device the completion block will be called right away and no error will be returned
/// - Parameter completion: completion block returning a NSError in case something has gone wrong while syncing the blocklist with the VPN node
- (void)syncBlocklistWithCompletion:(void (^ _Nullable)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
