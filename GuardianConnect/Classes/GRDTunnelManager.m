//
//  GRDTunnelManager.m
//  Guardian
//
//  Created by Kevin Bradley on 2/3/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

/**

 this is a singleton class because we want a singular reference point to NETunnelProvider manager, not one we would have to load asyncronously over and over due to infrastructure of the class described below.
 
 an NETunnelProviderManager class method manages an array of managers (of the type NETunnelProviderManager) that are loaded from preferences, we keep an instance of the active one rather than loading it every single time (we only need to save / load it if we turn it on or off)

 */

#import <GuardianConnect/GRDTunnelManager.h>
#import <GuardianConnect/Shared.h>
#import <GuardianConnect/EXTScope.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDCredential.h>
#import <GuardianConnect/GRDCredentialManager.h>

@interface GRDTunnelManager() {
    BOOL _isLoading;
	BOOL _tunnelLoaded;
}
@end

@implementation GRDTunnelManager

- (BOOL)isLoading {
	return _isLoading;
}

- (void)setIsLoading:(BOOL)loading {
	_isLoading = loading;
}

- (BOOL)tunnelLoaded {
	return _tunnelLoaded;
}

- (void)setTunnelLoaded:(BOOL)loaded {
	_tunnelLoaded = loaded;
}

+ (id)sharedManager {
    static dispatch_once_t pred;
    static GRDTunnelManager *shared;
    dispatch_once(&pred, ^{
        shared = [GRDTunnelManager new];
        [shared setIsLoading:NO];
        [shared setBlocklistEnabled:NO];
		[shared setTunnelLoaded:NO];
        
        [shared setIsLoading:YES];
        [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
            [shared setIsLoading:NO];
			[shared setTunnelLoaded:YES];
            if ([managers count] == 0) {
                GRDWarningLogg(@"No tunnel manager to load. Not creating a new one");
                
            } else {
                shared.tunnelProviderManager = [managers firstObject];
            }
        }];
    });
	
    return shared;
}

+ (BOOL)tunnelConnected {
    return ([[self sharedManager] currentTunnelProviderState] == NEVPNStatusConnected);
}

- (void)ensureTunnelManagerWithCompletion:(void (^_Nullable)(NETunnelProviderManager *_Nullable tunnelManager, NSString *_Nullable errorMessage))completion {
	if (self.tunnelProviderManager != nil) {
		if (completion) completion(self.tunnelProviderManager, nil);
		return;
	}
	
	[self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable errorMessage) {
		if (errorMessage && ![[errorMessage localizedDescription] isEqualToString:@"No tunnel provider managers setup!"]) {
			if (completion) completion(nil, [errorMessage localizedDescription]);
			return;
		
		} else if (manager == nil) {
			GRDWarningLogg(@"No tunnel provider manager installed. Creating and installing a new one");
#if TARGET_OS_OSX
			NETunnelProviderManager *tunnelManager = [NETunnelProviderManager new];

#else
			NETunnelProviderManager *tunnelManager = [NETunnelProviderManager new];
#endif


			GRDLogg(@"Successfully saved new tunnel provider manager");
			self.tunnelProviderManager = tunnelManager;
			if (completion) completion(tunnelManager, nil);
			return;

			
		} else {
			GRDLogg(@"Tunnel provider manager ready to go");
			self.tunnelProviderManager = manager;
			if (completion) completion(manager, nil);
			return;
		}
	}];
}

+ (void)tunnelConfiguredWithCompletion:(void (^)(BOOL))completion {
	[NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
		if ([managers count] == 0) {
			if (completion) completion(NO);
			return;
		}
		
		if (completion) completion(YES);
	}];
}

- (void)loadTunnelManagerFromPreferences:(void (^_Nullable)(NETunnelProviderManager * __nullable manager, NSError * __nullable errorMessage))completion {
	if ([self isLoading]) {
		if (completion) {
			completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Already loading tunnel manager preferences, dont do it again!"]);
		}
		return;
	}
	
	[self setIsLoading:YES];
	[NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
		[self setIsLoading:NO];
		if (error != nil) {
			if (completion) completion(nil, error);
			return;
		}
		
		[self setTunnelLoaded:YES];
		
		if (managers.count == 0) {
			if (completion) completion(nil, nil);
			
		} else {
			if (managers.count > 1) { //clear out any additional configs if there is more than one.
				NETunnelProviderManager *last = managers.lastObject;
				[last removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
					if (error != nil) {
						GRDErrorLogg(@"Failed to delete extra tunnel manager: %@", error);
					}
				}];
			}
			
			if (completion) completion(managers[0], nil);
		}
	}];
}

- (void)removeTunnelFromPreferences:(void (^)(NSError * _Nullable))completion {
	if (self.tunnelProviderManager == nil) {
		if (completion) completion(nil);
		return;
	}
	
	[self.tunnelProviderManager removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(error);
			return;
		}
		self.tunnelProviderManager = nil;
		if (completion) completion(nil);
		return;
	}];
}

/// Current status of the tunnel provider
- (NEVPNStatus)currentTunnelProviderState {
    __block NEVPNStatus currentStatus = NEVPNStatusInvalid;
    if (!self.tunnelProviderManager) {
		if ([self tunnelLoaded] == YES) {
			return currentStatus;
		}
		
        [self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable errorMessage) {
            if (manager && !errorMessage) {
                currentStatus = manager.connection.status;
            }
        }];
        return currentStatus;
		
    } else {
        return self.tunnelProviderManager.connection.status;
    }
}

- (void)currentTunnelProviderStateWithCompletion:(void (^)(NEVPNStatus, NSError * _Nullable))completion {
	if (self.tunnelProviderManager != nil) {
		if (completion) completion(self.tunnelProviderManager.connection.status, nil);
		return;
	}
		
	if ([self tunnelLoaded] == YES) {
		if (completion) completion(NEVPNStatusInvalid, nil);
		return;
	}
	
	[self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(NEVPNStatusInvalid, errorMessage);
			return;
		}
		
		if (manager != nil) {
			if (completion) completion(manager.connection.status, nil);
			return;
			
		} else {
			if (completion) completion(NEVPNStatusInvalid, nil);
			return;
		}
	}];
}

@end
