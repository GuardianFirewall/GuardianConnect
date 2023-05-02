//
//  GRDRegion.h
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDVPNHelper.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDRegion : NSObject <NSSecureCoding>

@property NSString *continent; 			//continent
@property NSString *countryISOCode; 	//country-iso-code
@property NSString *regionName; 		//name
@property NSString *displayName; 		//name-pretty
@property NSString *bestHost; 			//defaults to nil, is populated upon get server detail completion
@property NSString *bestHostLocation; 	//defaults to nil, is populated upon get server detail completion
@property BOOL isAutomatic; 			//experimental


/// Convenience method to parse an API response to a GRDRegion object
/// - Parameter regionDict: the dictionary with Guardian Connect API compatible key/value pairs
- (instancetype)initWithDictionary:(NSDictionary *)regionDict;

/// Returns the best server closest in proximity to the device
/// - Parameter completion: completion handler containing the VPN node hostname, location description and an indicator communicating successful or failed API interactions & processing
- (void)findBestServerWithCompletion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))completion;

/// Returns the best server closest in proximity to the device
/// - Parameters:
///   - feautreEnv: the desired Guardian server feature environment
///   - betaCapable: indicator whether the returned server should include beta features
///   - completion: completion handler containing the VPN node hostname, location description and an indicator communicating successful or failed API interactions & processing
- (void)findBestServerWithServerFeatureEnvironment:(GRDServerFeatureEnvironment)feautreEnv betaCapableServers:(BOOL)betaCapable completion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))completion;

/// Convenience method to return a GRDRegion object to set the client back to automatic routing to the nearest VPN server
+ (GRDRegion *)automaticRegion;

/// Convenience method to convert timezones from the server into more useful GRDRegion instances, handy for region picker views
+ (NSArray <GRDRegion*> *)regionsFromTimezones:(NSArray *_Nullable)timezones;

@end

NS_ASSUME_NONNULL_END
