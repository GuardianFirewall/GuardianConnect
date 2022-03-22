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
}
@end

@implementation GRDTunnelManager

- (BOOL)isLoading {
	return _isLoading;
}

- (void)setIsLoading:(BOOL)loading {
	_isLoading = loading;
}

+ (id)sharedManager {
    static dispatch_once_t pred;
    static GRDTunnelManager *shared;
    dispatch_once(&pred, ^{
        shared = [GRDTunnelManager new];
        [shared setIsLoading:false];
        [shared setBlocklistEnabled:false];
        
        [shared setIsLoading: YES];
        [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
            [shared setIsLoading:NO];
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
	
	[self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSString * _Nullable errorMessage) {
		if (errorMessage && ![errorMessage isEqualToString:@"No tunnel provider managers setup!"]) {
			if (completion) completion(nil, errorMessage);
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

/// Loads or creates our stored instance of the tunnelProviderManager
- (void)loadTunnelManagerFromPreferences:(void (^_Nullable)(NETunnelProviderManager * __nullable manager, NSString * __nullable errorMessage))completion {
	if (_isLoading) {
		if (completion) {
			completion(nil, @"Already loading tunnel manager preferences, dont do it again!");
		}
		return;
	}
	
	@weakify(self);
	_isLoading = YES;
	[NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
		self_weak_.isLoading = false;
		if (managers.count == 0) {
			if (completion) completion(nil, @"No tunnel provider managers setup!");
			
		} else {
			if (managers.count > 1) { //clear out any additional configs if there is more than one.
				NETunnelProviderManager *last = managers.lastObject;
				[last removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
					GRDErrorLogg(@"Failed to delete extra tunnel manager: %@", error);
				}];
			}
			
			if (completion) completion(managers[0], nil);
		}
	}];
}

- (BOOL)updateTunnelSettings:(BOOL)turnOn {
    __block BOOL _success = true;
    self.tunnelProviderManager.onDemandEnabled = turnOn;
    self.tunnelProviderManager.enabled = turnOn;
    self.tunnelProviderManager.onDemandRules = [GRDTunnelManager onDemandRules];
    [[NSUserDefaults standardUserDefaults] setBool:turnOn forKey:kGRDTunnelEnabled];
    @weakify(self);
    [self.tunnelProviderManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            _success = false;
            [self_weak_.tunnelProviderManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                self_weak_.tunnelProviderManager = nil;
                [self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSString * _Nullable errorMessage) {
                    if (errorMessage) {
                        _success = false;
						
                    } else {
                        _success = true;
                    }
                }];
            }];
			
        } else {
            self_weak_.tunnelProviderManager = nil;
            [self_weak_ loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSString * _Nullable errorMessage) {
                if (errorMessage) {
                    _success = false;
					
                } else {
                    _success = true;
                }
            }];
        }
    }];
    return _success;
}

/// Toggle the state on or off for the PacketTunnelProvider
- (BOOL)toggleTunnelProviderState {
    BOOL _success = true;
    switch ([self currentTunnelProviderState]) {
        
        case NEVPNStatusConnected:
            
            //[self.tunnelProviderManager.connection stopVPNTunnel];
            [self updateTunnelSettings:false];
            break;
        case NEVPNStatusInvalid:
        case NEVPNStatusDisconnected:
            _success = [self updateTunnelSettings:true];
            break;
            
        default:
            break;
    }
    return _success;
}

/// Current status of the tunnel provider
- (NEVPNStatus)currentTunnelProviderState {
    __block NEVPNStatus currentStatus = NEVPNStatusInvalid;
    if (!self.tunnelProviderManager) {
        [self loadTunnelManagerFromPreferences:^(NETunnelProviderManager * _Nullable manager, NSString * _Nullable errorMessage) {
            if (manager && !errorMessage) {
                currentStatus = manager.connection.status;
            }
        }];
        return currentStatus;
		
    } else {
        return self.tunnelProviderManager.connection.status;
    }
}

+ (NSArray <NEOnDemandRuleConnect *> *)onDemandRules {
	NEOnDemandRuleConnect *connectRule = [NEOnDemandRuleConnect new];
	connectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
	return @[connectRule];
}



@end
