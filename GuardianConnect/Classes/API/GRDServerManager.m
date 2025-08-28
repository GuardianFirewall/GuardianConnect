//
//  GRDServerManager.m
//  Guardian
//
//  Created by will on 6/21/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@interface GRDServerManager()

@property GRDHousekeepingAPI 			*housekeeping;
@property NSString 						*regionPrecision;
@property GRDServerFeatureEnvironment 	featureEnv;
@property BOOL 							betaCapable;

@end

@implementation GRDServerManager

- (instancetype)init {
    if (self = [super init]) {
        self.housekeeping 		= [[GRDHousekeepingAPI alloc] init];
		self.regionPrecision 	= kGRDRegionPrecisionDefault;
		self.featureEnv 		= ServerFeatureEnvironmentProduction;
		self.betaCapable 		= NO;
    }
    return self;
}

- (instancetype)initWithServerFeatureEnvironment:(GRDServerFeatureEnvironment)featureEnv betaCapableServers:(BOOL)betaCapable {
	self = [super init];
	if (self) {
		self.housekeeping 		= [[GRDHousekeepingAPI alloc] init];
		self.regionPrecision 	= kGRDRegionPrecisionDefault;
		self.featureEnv 		= featureEnv;
		self.betaCapable 		= betaCapable;
	}
	
	return self;
}

- (instancetype)initWithRegionPrecision:(NSString *)precision serverFeatureEnvironment:(GRDServerFeatureEnvironment)featureEnv betaCapableServers:(BOOL)betaCapable {
	self = [super init];
	if (self) {
		self.housekeeping 		= [[GRDHousekeepingAPI alloc] init];
		self.regionPrecision 	= precision;
		self.featureEnv 		= featureEnv;
		self.betaCapable 		= betaCapable;
	}
	
	return self;
}

- (void)selectGuardianHostWithCompletion:(void (^)(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage))completion {
    [self getGuardianHostsWithCompletion:^(NSArray * _Nullable servers, NSError * _Nullable errorMessage) {
        if (servers == nil) {
            if (completion) completion(nil, errorMessage);
            return;
        }
        
        // The server selection logic tries to prioritize low capacity servers which is defined as
        // having few clients connected. Low is defined as a capacity score of 0 or 1
        // capcaity score != connected clients. It's a calculated value based on information from each VPN node
        // this predicate will filter out anything above 1 as its capacity score
        NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
        
        // if at least 2 low capacity servers are not available, just use full list instead
        // helps mitigate edge case: single server returned, but it is down yet not reported as such by Housekeeping
        if ([availableServers count] < 2) {
            // take full list of servers returned by housekeeping and use them
            availableServers = servers;
            GRDWarningLogg(@"Fewer than 2 low capacity servers available. Using all servers");
        }
        
        // Get a random index based on the length of availableServers
        // Then use that random index to select a hostname and return it to the caller
        NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
		NSDictionary *serverDict = [availableServers objectAtIndex:randomIndex];
		GRDSGWServer *server = [[GRDSGWServer alloc] initFromDictionary:serverDict];
        if (completion) completion(server, nil);
    }];
}

- (void)getGuardianHostsWithCompletion:(void (^)(NSArray * _Nullable servers, NSError * _Nullable errorMessage))completion {
	GRDRegion *preferredRegion = [[GRDVPNHelper sharedInstance] selectedRegion];
	if (preferredRegion != nil) {
		NSString *regionName = preferredRegion.regionName;
		// This is only meant as a fallback to have something
		// when absolutely everything seems to have fallen apart
		// The same strategy is taken server side
		if (regionName == nil) {
			GRDWarningLogg(@"Setting region to us-east to recover");
			regionName = @"us-east";
		}
		
		[self.housekeeping requestServersForRegion:regionName regionPrecision:self.regionPrecision paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nullable servers, NSError * _Nullable error) {
			if (completion) completion(servers, error);
			return;
		}];
		
	} else {
		[self selectAutomaticModeRegion:^(GRDRegion *automaticRegion, NSError *error) {
			if (error != nil) {
				if (completion) completion(nil, error);
				return;
			}
			
			
			// This is only meant as a fallback to have something
			// when absolutely everything seems to have fallen apart
			// The same strategy is taken server side
			if (automaticRegion == nil) {
				GRDWarningLogg(@"Failed to find time zone: %@", [NSTimeZone localTimeZone]);
				GRDWarningLogg(@"Setting time zone to us-east-coast");
				automaticRegion = [GRDRegion failSafeRegionForRegionPrecision:self.regionPrecision];
				
			} else {
				//
				// Note from CJ 2024-07-12
				// Storing a GRDRegion reference to the last known automatic region
				// incl. the time zone name to be able to check later on whether
				// the device has potentially physically moved to another region where
				// it should
				automaticRegion.timeZoneName = [[NSTimeZone localTimeZone] name];
				NSError *encodeError;
				NSData *regionData = [NSKeyedArchiver archivedDataWithRootObject:automaticRegion requiringSecureCoding:YES error:&encodeError];
				if (encodeError != nil) {
					GRDErrorLogg(@"Failed to encode GRDRegion for storage in NSUserDefaults: %@", [encodeError localizedDescription]);
					
				} else {
					[[NSUserDefaults standardUserDefaults] setObject:regionData forKey:kGRDLastKnownAutomaticRegion];
				}
			}
			
			//
			// Note from CJ 2024-02-19
			// Hard coding the region precision to default here because we're going by the device's
			// time zone which are mapped to the default regions in our system.
			[self.housekeeping requestServersForRegion:automaticRegion.regionName regionPrecision:kGRDRegionPrecisionDefault paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nullable servers, NSError * _Nullable error) {
				if (completion) completion(servers, error);
			}];
		}];
	}
}

- (void)selectAutomaticModeRegion:(void (^)(GRDRegion *automaticRegion, NSError *error))completion {
	[self.housekeeping requestTimeZonesForRegionsWithCompletion:^(NSArray * _Nullable timeZones, NSError * _Nullable error) {
		if (error != nil) {
			GRDErrorLogg(@"Failed to get timezones from housekeeping: %@", [error localizedDescription]);
			if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Failed to request list of servers"]);
			return;
		}
		
		GRDRegion *automaticRegion = [GRDServerManager localRegionFromTimezones:timeZones];
		NSString *regionName = automaticRegion.regionName;
		NSTimeZone *local = [NSTimeZone localTimeZone];
		GRDDebugLog(@"Found region: %@", regionName);
		GRDDebugLog(@"Real local time zone: %@", local);
		
		if (completion) completion(automaticRegion, nil);
	}];
}

- (void)findBestHostInRegion:(GRDRegion * _Nullable)region completion:(void(^_Nullable)(GRDSGWServer * _Nullable server, NSError *error))completion {
    if (region == nil) {
        GRDDebugLog(@"Region is nil, using automatic routing logic!");
        GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
        if (mainCredentials != nil) {
            if (completion) {
				GRDSGWServer *server = [mainCredentials sgwServerFormat];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(server, nil);
                });
            }
            
        } else {
			GRDDebugLog(@"Host or host location not yet set");
            [self selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        GRDDebugLog(@"hostname: %@; display-name: %@; error: %@", server.hostname, server.displayName, [errorMessage localizedDescription]);
                        completion(server, errorMessage);
                    });
                }
            }];
        }
        
        return;
    }
	
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[self.housekeeping requestServersForRegion:region.regionName regionPrecision:region.regionPrecision paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nullable servers, NSError * _Nullable error) {
            if (servers.count < 1) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
						completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:NSLocalizedString(@"No server found", nil)]);
						return;
                    });
                }
				
            } else {
                NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
                if (availableServers.count < 2) {
                    availableServers = servers;
                }
                
                NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
				NSDictionary *serverDict = [availableServers objectAtIndex:randomIndex];
				GRDSGWServer *server = [[GRDSGWServer alloc] initFromDictionary:serverDict];
                GRDDebugLog(@"Selected host: %@", server);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(server, nil);
                    });
                }
            }
        }];
    });
}

+ (GRDRegion *)localRegionFromTimezones:(NSArray *)timezones {
    NSDictionary *found = [[timezones filteredArrayUsingPredicate:[NSPredicate timezonePredicate]] lastObject];
    return [[GRDRegion alloc] initWithDictionary:found];
}

- (void)getRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> * _Nullable regions))completion {
	[[GRDHousekeepingAPI new] requestAllServerRegionsWithPrecision:kGRDRegionPrecisionDefault completion:^(NSArray<NSDictionary *> * _Nullable items, NSError * _Nullable error) {
		if (error != nil) {
			GRDErrorLogg(@"Failed to fetch server regions from API. Error: %@", [error localizedDescription]);
			if (completion) completion(nil);
			return;
		}
		
		if (completion) completion([GRDRegion regionsFromTimezones:items]);
		return;
	}];
}

- (void)allRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> * _Nullable, NSError * _Nullable))completion {
	[self.housekeeping requestAllServerRegionsWithPrecision:self.regionPrecision completion:^(NSArray<NSDictionary *> * _Nullable items, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(nil, error);
			return;
		}
		
		if (completion) completion([GRDRegion regionsFromTimezones:items], nil);
		return;
	}];
}

@end
