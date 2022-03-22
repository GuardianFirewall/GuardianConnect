//
//  GRDServerManager.m
//  Guardian
//
//  Created by will on 6/21/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import <GuardianConnect/GRDDebugHelper.h>
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@interface GRDServerManager()

@property GRDHousekeepingAPI *housekeeping;
@property GRDServerFeatureEnvironment featureEnv;
@property BOOL betaCapable;

@end

@implementation GRDServerManager

- (instancetype)init {
    if (self = [super init]) {
        self.housekeeping = [[GRDHousekeepingAPI alloc] init];
		self.featureEnv = ServerFeatureEnvironmentProduction;
		self.betaCapable = NO;
    }
    return self;
}

- (instancetype)initWithServerFeatureEnvironment:(GRDServerFeatureEnvironment)featureEnv betaCapableServers:(BOOL)betaCapable {
	self = [super init];
	if (self) {
		self.housekeeping = [[GRDHousekeepingAPI alloc] init];
		self.featureEnv = featureEnv;
		self.betaCapable = betaCapable;
	}
	
	return self;
}

- (void)selectGuardianHostWithCompletion:(void (^)(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage))completion {
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"selectGuardianHostWithCompletion"];
    [self getGuardianHostsWithCompletion:^(NSArray * _Nullable servers, NSString * _Nullable errorMessage) {
        [debugHelper logTimeWithMessage:@"getGuardianHostsWithCompletion completion handler"];
        if (servers == nil) {
            if (completion) completion(nil, nil, errorMessage);
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
            GRDWarningLogg(@"Less than 2 low cap servers available. Using all servers");
        }
		
        [debugHelper logTimeWithMessage:@"created availableServers array"];
        
        // Get a random index based on the length of availableServers
        // Then use that random index to select a hostname and return it to the caller
        NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
        NSString *host = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
        NSString *hostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
        GRDLogg(@"Selected hostname: %@", host);
        if (completion) completion(host, hostLocation, nil);
        [debugHelper logTimeWithMessage:@"getGuardianHostsWithCompletion end"];
    }];
}

- (void)getGuardianHostsWithCompletion:(void (^)(NSArray * _Nullable servers, NSString * _Nullable errorMessage))completion {
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"getGuardianHostsWithCompletion"];
    
    [self.housekeeping requestTimeZonesForRegionsWithCompletion:^(NSArray * _Nonnull timeZones, BOOL success, NSUInteger responseStatusCode) {
        [debugHelper logTimeWithMessage:@"housekeeping.requestTimeZonesForRegionsWithTimestamp completion block start"];
        if (success == NO) {
            GRDLogg(@"Failed to get timezones from housekeeping: %ld", responseStatusCode);
            if (completion) completion(nil, @"Failed to request list of servers");
            return;
        }
        
        GRDRegion *region = [GRDServerManager localRegionFromTimezones:timeZones];
        NSString *regionName = region.regionName;
        NSTimeZone *local = [NSTimeZone localTimeZone];
        GRDDebugLog(@"Found region: %@", regionName);
		GRDDebugLog(@"Real local time zone: %@", local);
        
        // This is how region / server selection works, if the selected credential isnt nil, we are using a custom region.
        GRDRegion *selectedRegion = [[GRDVPNHelper sharedInstance] selectedRegion];
        if (selectedRegion) {
			GRDDebugLog(@"Using custom selected region: %@", selectedRegion.regionName);
            regionName = selectedRegion.regionName;
        }
        
        // This is only meant as a fallback to have something
        // when absolutely everything seems to have fallen apart
        // The same strategy is taken server side
        if (regionName == nil) {
            GRDWarningLogg(@"Failed to find time zone: %@", local);
			GRDWarningLogg(@"Setting time zone to us-east");
            regionName = @"us-east";
        }
        
        // Note from CJ 2021-10-25:
        // Hardcoded to ServerFeatureEnvironmentProduction for the time being. Going to make this a little more
        // flexbile very soon to enable features in Guardian
        [self.housekeeping requestServersForRegion:regionName paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (success == false) {
				GRDWarningLogg(@"Failed to get servers for region");
                if (completion) completion(nil, @"Failed to request list of servers.");
                return;
                
            } else {
                if (completion) completion(servers, nil);
            }
        }];
        [debugHelper logTimeWithMessage:@"housekeeping.requestTimeZonesForRegionsWithTimestamp completion block end"];
    }];
}

- (void)findBestHostInRegion:(NSString * _Nullable )regionName completion:(void(^_Nullable)(NSString *host, NSString *hostLocation, NSString *error))completion {
    if (regionName == nil) { //if the region is nil, use the current one
        GRDDebugLog(@"Nil region, use the default!");
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        GRDCredential *creds = [GRDCredentialManager mainCredentials];
        NSString *host = [def objectForKey:kGRDHostnameOverride];
        NSString *hl = [def objectForKey:kGRDVPNHostLocation];
        if (creds) {
            host = [creds hostname];
            hl = [creds hostnameDisplayValue];
        }
        
        if (host && hl) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(host, hl, nil);
                });
            }
            
        } else {
            //we dont have a host and hostlocation yet.
            GRDLog(@"we dont have a host or host location yet");
            [self selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        GRDLog(@"host: %@ loc: %@ error: %@", guardianHost, guardianHostLocation, errorMessage);
                        completion(guardianHost, guardianHostLocation, errorMessage);
                    });
                }
            }];
        }
        
        return;
    }
	
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.housekeeping requestServersForRegion:regionName paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (servers.count < 1) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, nil, NSLocalizedString(@"No server found", nil));
                    });
                }
				
            } else {
                NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
                if (availableServers.count < 2) {
                    availableServers = servers;
                }
                
                NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
                NSString *guardianHost = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
                NSString *guardianHostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
                GRDLog(@"Selected host: %@", guardianHost);
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(guardianHost, guardianHostLocation, nil);
                    });
                }
            }
        }];
    });
}

- (void)selectBestHostFromRegion:(NSString *)regionName completion:(void(^_Nullable)(NSString *errorMessage, BOOL success))completion {
    GRDLog(@"Requested Region: %@", regionName);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self.housekeeping requestServersForRegion:regionName paidServers:[GRDSubscriptionManager isPayingUser] featureEnvironment:self.featureEnv betaCapableServers:self.betaCapable completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (servers.count < 1) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(@"No server found in the specified region", NO);
                    });
                }
                
            } else {
                NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
                if (availableServers.count < 2) {
                    GRDDebugLog(@"Less than 2 low capacity servers: %@", availableServers);
                    availableServers = servers;
                }
                
                NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
                NSString *guardianHost = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
                NSString *guardianHostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
                GRDLog(@"Selected host: %@", guardianHost);
                GRDVPNHelper *vpnHelper = [GRDVPNHelper sharedInstance];
				[vpnHelper configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation postCredential:nil completion:^(BOOL success, NSString * _Nonnull errorMessage) {
                    if (!success) {
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(errorMessage, NO);
                            });
                        }
                        
                    } else {
                        GRDDebugLog(@"Configured first time user successfully!");
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(nil, YES);
                            });
                        }
                    }
                }];
            }
        }];
    });
}

+ (GRDRegion *)localRegionFromTimezones:(NSArray *)timezones {
    NSDictionary *found = [[timezones filteredArrayUsingPredicate:[NSPredicate timezonePredicate]] lastObject];
    return [[GRDRegion alloc] initWithDictionary:found];
}

- (void)getRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> *regions))completion {
	[[GRDHousekeepingAPI new] requestAllServerRegions:^(NSArray<NSDictionary *> * _Nullable items, BOOL success) {
		if (!success) {
			GRDErrorLogg(@"Failed to fetch server regions from API");
			if (completion) completion(nil);
			return;
		}
		
		if (completion) completion([GRDRegion regionsFromTimezones:items]);
		return;
	}];
}

@end
