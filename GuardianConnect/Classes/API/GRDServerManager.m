//
//  GRDServerManager.m
//  Guardian
//
//  Created by will on 6/21/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

@import UserNotifications;
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDDebugHelper.h>

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#endif

@interface GRDServerManager() {
    GRDNetworkHealthType networkHealth;
}
@property GRDHousekeepingAPI *housekeeping;
@end

@implementation GRDServerManager

- (instancetype)init {
    if (self = [super init]) {
        self.housekeeping = [[GRDHousekeepingAPI alloc] init];
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
        
        // Array of servers out of which ultimately a host for the client will be randomly selected
        NSArray *availableServers = [NSArray new];
        
        // Checking to see if the clients prefers beta-capable servers over production servers
        BOOL betaCapablePreferred = [[NSUserDefaults standardUserDefaults] boolForKey:@"kGRDBetaCapablePreferred"];
        if (betaCapablePreferred == YES) {
            availableServers = [servers filteredArrayUsingPredicate:[NSPredicate betaCapablePredicate]];
            if ([availableServers count] < 1) {
                GRDLog(@"No beta capable hosts available in the current region, following regular client load balancing logic");
            }
        }
        
        // If availableServers is has a count of < 1 (aka. 0)
        // because either the client didn't ask for beta-capable servers
        // or because there were no beta capable servers availble
        if ([availableServers count] < 1) {
            // The server selection logic tries to prioritize low capacity servers which is defined as a capacity score of 0 or 1
            // capcaity score != connected clients. It's a calculated value based on information from each VPN node
            // this predicate will filter out anything above 1 as its capacity score
            availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
            
            // if at least 2 low capacity servers are not available, just use full list instead
            // helps mitigate edge case: single server returned, but it is down yet not reported as such by Housekeeping
            if ([availableServers count] < 2) {
                // take full list of servers returned by housekeeping and use them
                availableServers = servers;
                GRDLog(@"Fewer than 2 low capacity score server available, using all available servers");
            }
        }
        
        
        [debugHelper logTimeWithMessage:@"created availableServers array"];
        
        // Get a random index based on the length of availableServers
        // Then use that random index to select a hostname and return it to the caller
        NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
        NSString *host = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
        NSString *hostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
        GRDLog(@"Selected hostname: %@", host);
        if (completion) completion(host, hostLocation, nil);
        [debugHelper logTimeWithMessage:@"getGuardianHostsWithCompletion end"];
    }];
}

- (void)getGuardianHostsWithCompletion:(void (^)(NSArray * _Nullable servers, NSString * _Nullable errorMessage))completion {
    GRDDebugHelper *debugHelper = [[GRDDebugHelper alloc] initWithTitle:@"getGuardianHostsWithCompletion"];
    
    [self.housekeeping requestTimeZonesForRegionsWithCompletion:^(NSArray * _Nonnull timeZones, BOOL success, NSUInteger responseStatusCode) {
        [debugHelper logTimeWithMessage:@"housekeeping.requestTimeZonesForRegionsWithTimestamp completion block start"];
        if (success == NO) {
            GRDLog(@"Failed to get timezones from housekeeping: %ld", responseStatusCode);
            if (completion) completion(nil, @"Failed to request list of servers");
            return;
        }
        
        GRDRegion *region = [GRDServerManager localRegionFromTimezones:timeZones];
        NSString *regionName = region.regionName;
        NSTimeZone *local = [NSTimeZone localTimeZone];
        GRDLog(@"[DEBUG] found region: %@", regionName);
        GRDLog(@"[DEBUG] real local time zone: %@", local);
        
        // This is how region / server selection works, if the selected credential isnt nil, we are using a custom region.
        GRDRegion *selectedRegion = [[GRDVPNHelper sharedInstance] selectedRegion];
        if (selectedRegion) {
            GRDLog(@"Using custom selected region: %@", selectedRegion.regionName);
            regionName = selectedRegion.regionName;
        }
        
        // This is only meant as a fallback to have something
        // when absolutely everything seems to have fallen apart
        // The same strategy is taken server side
        if (regionName == nil) {
            GRDLog(@"Failed to find time zone: %@", local);
            GRDLog(@"Setting time zone to us-east");
            regionName = @"us-east";
        }
        
        // Note from CJ 2021-10-25:
        // Hardcoded to ServerFeatureEnvironmentProduction for the time being. Going to make this a little more
        // flexbile very soon to enable features in Guardian
        [self.housekeeping requestServersForRegion:regionName featureEnvironment:ServerFeatureEnvironmentProduction completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (success == false) {
                GRDLog(@"Failed to get servers for region");
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
        GRDLog(@"[DEBUG] nil region, use the default!");
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        GRDCredential *creds = [GRDCredentialManager mainCredentials];
        NSString *host = [def objectForKey:kGRDHostnameOverride];
        NSString *hl = [def objectForKey:kGRDVPNHostLocation];
        if (creds) {
            host = [creds hostname];
            hl = [creds hostnameDisplayValue];
        }
        
        if (host && hl) {
            if(completion) {
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
        GRDHousekeepingAPI *housekeeping = [[GRDHousekeepingAPI alloc] init];
        [housekeeping requestServersForRegion:regionName featureEnvironment:ServerFeatureEnvironmentProduction completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (servers.count < 1){
                if (completion){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil, nil, NSLocalizedString(@"No server found", nil));
                    });
                }
            } else {
                NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
                if (availableServers.count < 2){
                    availableServers = servers;
                }
                
                NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
                NSString *guardianHost = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
                NSString *guardianHostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
                GRDLog(@"Selected host: %@", guardianHost);
                if(completion){
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
        GRDHousekeepingAPI *housekeeping = [[GRDHousekeepingAPI alloc] init];
        [housekeeping requestServersForRegion:regionName featureEnvironment:ServerFeatureEnvironmentProduction completion:^(NSArray * _Nonnull servers, BOOL success) {
            if (servers.count < 1) {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NSLocalizedString(@"No server found", nil),FALSE);
                    });
                }
                
            } else {
                NSArray *availableServers = [servers filteredArrayUsingPredicate:[NSPredicate capacityPredicate]];
                if (availableServers.count < 2) {
                    GRDLog(@"[DEBUG] less than 2 low capacity servers: %@", availableServers);
                    availableServers = servers;
                }
                
                NSUInteger randomIndex = arc4random_uniform((unsigned int)[availableServers count]);
                NSString *guardianHost = [[availableServers objectAtIndex:randomIndex] objectForKey:@"hostname"];
                NSString *guardianHostLocation = [[availableServers objectAtIndex:randomIndex] objectForKey:@"display-name"];
                GRDLog(@"Selected host: %@", guardianHost);
                GRDVPNHelper *vpnHelper = [GRDVPNHelper sharedInstance];
                [vpnHelper configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation completion:^(BOOL success, NSString * _Nonnull errorMessage) {
                    if (!success) {
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(errorMessage,FALSE);
                            });
                        }
                        
                    } else {
                        GRDLog(@"[DEBUG] configured first time user successfully!");
                        [self bindPushToken];
                        if (completion) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completion(nil,TRUE);
                            });
                        }
                    }
                }];
            }
        }];
    });
}

- (void)populateTimezonesIfNecessaryWithCompletion:(void(^_Nullable)(NSArray *regions))completion {
    __block NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSNumber *timestamp = [ud objectForKey:kGuardianAllRegionsTimeStamp];
    if (timestamp != nil) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.integerValue];
        NSTimeInterval intervalSinceNow = [[NSDate date] timeIntervalSinceDate:date];
        if (intervalSinceNow > 60*10){ //its been more than 10 minutes, time to refresh the data!
            [ud removeObjectForKey:kGuardianAllRegions];
        }
    }
    NSArray *regions = [ud valueForKey:kGuardianAllRegions];
    if (!regions){
        [[GRDHousekeepingAPI new] requestAllServerRegions:^(NSArray<NSDictionary *> * _Nullable items, BOOL success) {
            NSTimeInterval nowUnix = [[NSDate date] timeIntervalSince1970];
            [ud setObject:[NSNumber numberWithInt:nowUnix] forKey:kGuardianAllRegionsTimeStamp];
            [ud setObject:[items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name-pretty" ascending:true]]] forKey:kGuardianAllRegions];
            if (completion){
                completion(items);
            }
        }];
    } else {
        if (completion){
            completion(regions);
        }
    }
}

+ (GRDRegion *)localRegionFromTimezones:(NSArray *)timezones {
    NSDictionary *found = [[timezones filteredArrayUsingPredicate:[NSPredicate timezonePredicate]] lastObject];
    return [[GRDRegion alloc] initWithDictionary:found];
}

- (void)getRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> * _Nonnull regions))completion {
    [self populateTimezonesIfNecessaryWithCompletion:^(NSArray * _Nonnull regions) {
        if (completion){
            completion([GRDRegion regionsFromTimezones:regions]);
        }
    }];
}

/**
 
 the logic for this is simple, we need a delay to make sure we are actually connected to the server so the details get synced properly
 don't want to request push notification access if they haven't already accepted it, so this will only bind the push token if they have
 given permission to receive push notifications to begin with.
 
 */

- (void)bindPushToken {
    if (![GRDVPNHelper proMode]) {
          return;
    }
    if (@available(macOS 10.14, iOS 10.0, *)) {
        //doing this on a delay to make sure the settings get synced w/ the new server properly, without the delay it happens too fast.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_OSX
                            [[NSApplication sharedApplication] registerForRemoteNotifications];
#else
                            [[UIApplication sharedApplication] registerForRemoteNotifications];
#endif
                        });
                    });
                }
            }];
        });
    }
}

@end
