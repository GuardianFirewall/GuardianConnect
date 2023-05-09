//
//  GRDVPNHelper.m
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/EXTScope.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>
#import <GuardianConnect/GuardianConnect-Swift.h>

@import UserNotifications;

@interface GRDVPNHelper()

@end

@implementation GRDVPNHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GRDVPNHelper *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GRDVPNHelper alloc] init];
        shared.onDemand = YES;
		shared.ikev2VPNManager = [NEVPNManager sharedManager];
        [shared.ikev2VPNManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                shared.vpnLoaded = NO;
                shared.lastErrorMessage = error.localizedDescription;
				
            } else {
                shared.vpnLoaded = YES;
            }
        }];
		shared->_featureEnvironment = ServerFeatureEnvironmentProduction;
        [shared _loadCredentialsFromKeychain];
        [shared setTunnelManager:[GRDTunnelManager sharedManager]];
    });
    
    return shared;
}

- (BOOL)isConnected {
	NEVPNStatus ikev2Status 	= [[[NEVPNManager sharedManager] connection] status];
	NEVPNStatus grdTunnelstatus = [[[[[GRDVPNHelper sharedInstance] tunnelManager] tunnelProviderManager] connection] status];
    
	return (ikev2Status == NEVPNStatusConnected || grdTunnelstatus == NEVPNStatusConnected);
}

- (BOOL)isConnecting {
	NEVPNStatus ikev2Status = [[[NEVPNManager sharedManager] connection] status];
	NEVPNStatus grdTunnelstatus = [[[[[GRDVPNHelper sharedInstance] tunnelManager] tunnelProviderManager] connection] status];
	
	return (ikev2Status == NEVPNStatusConnecting || grdTunnelstatus == NEVPNStatusConnecting);
}

- (void)_loadCredentialsFromKeychain {
	GRDCredential *main = [GRDCredentialManager mainCredentials];
	[self setMainCredential:main];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:kGuardianUseFauxTimeZone]) {
		GRDRegion *region = [[GRDRegion alloc] init];
		region.regionName = [defaults valueForKey:kGuardianFauxTimeZone];
		region.displayName = [defaults valueForKey:kGuardianFauxTimeZonePretty];
		_selectedRegion = region;
	}
}

+ (BOOL)activeConnectionPossible {
    GRDCredential *cred = [GRDCredentialManager mainCredentials];
	if (cred.transportProtocol == TransportIKEv2) {
		NSString *apiHostname = cred.hostname;
		NSString *authToken = cred.apiAuthToken;
		NSString *eapUsername = cred.username;
		if (apiHostname == nil || authToken == nil || eapUsername == nil) return NO;
		return YES;
		
	} else if (cred.transportProtocol == TransportWireGuard) {
		if (cred.hostname == nil || cred.apiAuthToken == nil || cred.devicePrivateKey == nil || cred.serverPublicKey == nil) return  NO;
		return YES;
	
    } else {
        return NO;
    }
}

+ (void)clearVpnConfiguration {
    GRDCredential *creds = [GRDCredentialManager mainCredentials];
    if (creds != nil) {
        NSString *clientId;
        if (creds.transportProtocol == TransportIKEv2) {
            clientId = [creds username];
        
        } else if (creds.transportProtocol == TransportWireGuard) {
            clientId = [creds clientId];
        }
        
		[[GRDVPNHelper sharedInstance] getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential * _Nullable subscriberCredential, NSString * _Nullable error) {
			[[GRDGatewayAPI new] invalidateCredentialsForClientId:clientId apiToken:creds.apiAuthToken hostname:creds.hostname subscriberCredential:subscriberCredential.jwt completion:^(BOOL success, NSString * _Nullable errorMessage) {
				if (success == NO) {
					GRDErrorLog(@"Failed to invalidate VPN credentials: %@", errorMessage);
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
						[[GRDGatewayAPI new] invalidateCredentialsForClientId:clientId apiToken:creds.apiAuthToken hostname:creds.hostname subscriberCredential:[GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential] completion:^(BOOL success, NSString * _Nullable errorMessage) {
							if (success == NO) {
								GRDErrorLog(@"Failed to invalidate VPN credentials after waiting 1 second: %@", errorMessage);
								
							}
						}];
					});
				}
			}];
		}];
    }
    
    
    [GRDKeychain removeGuardianKeychainItems];
    [GRDCredentialManager clearMainCredentials];
    [[GRDVPNHelper sharedInstance] setMainCredential:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kGRDHostnameOverride];
    [defaults removeObjectForKey:kGRDVPNHostLocation];
    [defaults setBool:NO forKey:kAppNeedsSelfRepair];
    
    // make sure Settings tab UI updates to not erroneously show name of cleared server
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}

+ (void)saveAllInOneBoxHostname:(NSString *)host {
	[[NSUserDefaults standardUserDefaults] setObject:host forKey:kGRDHostnameOverride];
}

+ (void)sendServerUpdateNotifications {
	[[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}


# pragma mark - VPN Start Convenience Functions

- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:_featureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSError * _Nullable errorMessage) {
		if (!errorMessage) {
			[self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation postCredential:mid completion:completion];
			
		} else {
			if (completion) {
				completion(NO, [errorMessage localizedDescription]);
			}
		}
	}];
}

- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol postCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:_featureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSError * _Nullable errorMessage) {
		if (!errorMessage) {
			[self configureFirstTimeUserForTransportProtocol:protocol hostname:guardianHost andHostLocation:guardianHostLocation postCredential:mid completion:completion];
			
		} else {
			if (completion) {
				completion(NO, [errorMessage localizedDescription]);
			}
		}
	}];
}

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol postCredentialCallback:(void (^)(void))postCredentialCallback completion:(void (^)(NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:_featureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(errorMessage);
			return;
		}
		
		[self configureUserFirstTimeForTransportProtocol:protocol hostname:guardianHost andHostLocation:guardianHostLocation postCredential:postCredentialCallback completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
			if (completion) completion(errorMessage);
			return;
		}];
	}];
}

- (void)configureFirstTimeUserWithRegion:(GRDRegion * _Nullable)region completion:(StandardBlock)completion {
	GRDDebugLog(@"Configure with region: %@ location: %@", region.bestHost, region.bestHostLocation);
	if (!region.bestHost && !region.bestHostLocation && region) {
		[region findBestServerWithCompletion:^(NSString * _Nonnull server, NSString * _Nonnull serverLocation, BOOL success) {
			if (success) {
				[self selectRegion:region];
				[self configureFirstTimeUserForHostname:server andHostLocation:serverLocation postCredential:nil completion:completion];
				
			} else {
				if (completion) {
					completion(NO, [NSString stringWithFormat:@"Failed to find a host for region: %@", region.displayName]);
				}
			}
		}];
		
	} else {
		[self selectRegion:region];
		[self configureFirstTimeUserPostCredential:nil completion:completion];
	}
}

- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol withRegion:(GRDRegion * _Nullable)region completion:(StandardBlock)completion {
	GRDDebugLog(@"Configure with region: %@ location: %@", region.bestHost, region.bestHostLocation);
	[self selectRegion:region];
	if (!region.bestHost && !region.bestHostLocation && region) {
		[region findBestServerWithServerFeatureEnvironment:self.featureEnvironment betaCapableServers:self.preferBetaCapableServers completion:^(NSString * _Nonnull server, NSString * _Nonnull serverLocation, BOOL success) {
			if (success) {
				[self configureFirstTimeUserForTransportProtocol:protocol hostname:server andHostLocation:serverLocation postCredential:nil completion:completion];
				
			} else {
				if (completion) {
					completion(NO, [NSString stringWithFormat:@"Failed to find a host for region: %@", region.displayName]);
				}
			}
		}];
		
	} else {
		[self configureFirstTimeUserForTransportProtocol:protocol postCredential:nil completion:completion];
	}
}

- (void)configureFirstTimeUserForHostname:(NSString * _Nonnull)host andHostLocation:(NSString * _Nonnull)hostLocation postCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[GRDVPNHelper saveAllInOneBoxHostname:host];
	[defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
	
	[self createStandaloneCredentialsForDays:30 completion:^(NSDictionary * _Nonnull creds, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"%@", errorMessage);
			if (completion) {
				completion(NO, errorMessage);
			}
			
		} else if (creds) {
			if (mid) {
				mid();
			}
			
			NSMutableDictionary *fullCreds = [creds mutableCopy];
			fullCreds[kGRDHostnameOverride] = host;
			fullCreds[kGRDVPNHostLocation] = hostLocation;
			NSInteger adjustedDays = [GRDVPNHelper _subCredentialDays];
			self.mainCredential = [[GRDCredential alloc] initWithFullDictionary:fullCreds validFor:adjustedDays isMain:YES];
			[self.mainCredential saveToKeychain];
			[GRDCredentialManager addOrUpdateCredential:self.mainCredential];
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
			[self configureAndConnectVPNWithCompletion:^(NSString * _Nonnull message, GRDVPNHelperStatusCode status) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (status == GRDVPNHelperFail) {
						if (message != nil) {
							if (completion) {
								completion(NO, message);
							}
							
						} else {
							if (completion) {
								completion(NO, @"Configuring VPN failed due to a unknown reason. Please reset your connection and try again.");
							}
						}
						
					} else {
						if (completion) {
							completion(YES, nil);
						}
					}
				});
			}];
			
		} else { //no error, but creds are nil too!
			if (completion) {
				completion(NO, @"Configuring VPN failed due to a credential creation issue. Please reset your connection and try again.");
			}
		}
	}];
}

- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol hostname:(NSString * _Nonnull)host andHostLocation:(NSString * _Nonnull)hostLocation postCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[GRDVPNHelper saveAllInOneBoxHostname:host];
	[defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
	
	[self createStandaloneCredentialsForTransportProtocol:protocol days:30 completion:^(NSDictionary * _Nonnull creds, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"%@", errorMessage);
			if (completion) {
				completion(NO, errorMessage);
			}
			
		} else if (creds) {
			if (mid) {
				mid();
			}
			
			NSMutableDictionary *fullCreds = [creds mutableCopy];
			fullCreds[kGRDHostnameOverride] = host;
			fullCreds[kGRDVPNHostLocation] = hostLocation;

			NSInteger adjustedDays = [GRDVPNHelper _subCredentialDays];
			self.mainCredential = [[GRDCredential alloc] initWithTransportProtocol:protocol fullDictionary:fullCreds validFor:adjustedDays isMain:YES];
			if (protocol == TransportIKEv2) {
				[self.mainCredential saveToKeychain];
			}
			
			[GRDCredentialManager addOrUpdateCredential:self.mainCredential];
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
			[self configureAndConnectVPNWithCompletion:^(NSString * _Nonnull message, GRDVPNHelperStatusCode status) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (status == GRDVPNHelperFail) {
						if (message != nil) {
							if (completion) {
								completion(NO, message);
							}
							
						} else {
							if (completion) {
								completion(NO, @"Configuring VPN failed due to a unknown reason. Please reset your connection and try again.");
							}
						}
						
					} else {
						if (completion) {
							completion(YES, nil);
						}
					}
				});
			}];
			
		} else { //no error, but creds are nil too!
			if (completion) {
				completion(NO, @"Configuring VPN failed due to a credential creation issue. Please reset your connection and try again.");
			}
		}
	}];
}

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol hostname:(NSString * _Nonnull)host andHostLocation:(NSString * _Nonnull)hostLocation postCredential:(void(^__nullable)(void))mid completion:(void(^_Nullable)(GRDVPNHelperStatusCode status, NSError *_Nullable errorMessage))completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[GRDVPNHelper saveAllInOneBoxHostname:host];
	[defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
	
	[self createStandaloneCredentialsForTransportProtocol:protocol days:30 completion:^(NSDictionary * _Nonnull creds, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"%@", errorMessage);
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:errorMessage]);
			return;
			
		} else if (creds) {
			if (mid) mid();
			
			NSMutableDictionary *fullCreds = [creds mutableCopy];
			fullCreds[kGRDHostnameOverride] = host;
			fullCreds[kGRDVPNHostLocation] = hostLocation;
			
			NSInteger adjustedDays = [GRDVPNHelper _subCredentialDays];
			self.mainCredential = [[GRDCredential alloc] initWithTransportProtocol:protocol fullDictionary:fullCreds validFor:adjustedDays isMain:YES];
			if (protocol == TransportIKEv2) {
				[self.mainCredential saveToKeychain];
			}
			
			[GRDCredentialManager addOrUpdateCredential:self.mainCredential];
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
			[self configureAndConnectVPNTunnelWithCompletion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (status == GRDVPNHelperFail) {
						if (errorMessage != nil) {
							if (completion) completion(status, errorMessage);
							
						} else {
							if (completion) {
								completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Configuring VPN failed due to a unknown reason. Please reset your connection and try again."]);
							}
						}
						
					} else {
						if (completion) completion(YES, nil);
					}
				});
			}];
			
		} else { //no error, but creds are nil too!
			if (completion) {
				completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Configuring VPN failed due to a credential creation issue. Please reset your connection and try again."]);
			}
		}
	}];
}

- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString * _Nullable error, GRDVPNHelperStatusCode statusCode))completion {
	__block NSUserDefaults *defaults 	= [NSUserDefaults standardUserDefaults];
	__block NSString *vpnServer 		= [defaults objectForKey:kGRDHostnameOverride];
	
	if ([defaults boolForKey:kAppNeedsSelfRepair] == YES) {
		GRDWarningLogg(@"App marked as self repair is being required. Migrating user!");
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:^(BOOL success, NSString *error) {
			if (completion) {
				if (success) {
					completion(nil, GRDVPNHelperSuccess);
					
				} else {
					completion(error, GRDVPNHelperFail);
				}
				
			} else {
				GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
			}
			return;
		}];
		return;
	}
	
	if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO && [vpnServer hasSuffix:@".ikev2.network"] == NO) {
		GRDErrorLogg(@"Something went wrong! Bad server (%@). Migrating user...", vpnServer);
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:^(BOOL success, NSString *error) {
			if (completion) {
				if (success) {
					completion(nil, GRDVPNHelperSuccess);
					
				} else {
					completion(error, GRDVPNHelperFail);
				}
				
			} else {
				GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
			}
			return;
		}];
		return;
	}
	
	[[GRDGatewayAPI new] getServerStatusWithCompletion:^(NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"VPN server status check failed with error: %@", errorMessage);
			[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
				if (completion) {
					if (success) {
						completion(nil, GRDVPNHelperSuccess);
						
					} else {
						completion(error, GRDVPNHelperFail);
					}
					
				} else {
					GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
				}
				return;
			}];
			return;
		}
		
		if ([self.mainCredential transportProtocol] == TransportIKEv2) {
			NSString *apiAuthToken  = [self.mainCredential apiAuthToken];
			NSString *eapUsername   = [self.mainCredential username];
			NSData *eapPassword     = [self.mainCredential passwordRef];
			
			if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
				GRDDebugLog(@"EAP username: %@", eapUsername);
				GRDDebugLog(@"EAP password: %@", eapPassword);
				GRDDebugLog(@"EAP api auth token: %@", apiAuthToken);
				GRDErrorLogg(@"[IKEv2] Missing one or more required credentials, migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
					if (completion) {
						if (success) {
							completion(nil, GRDVPNHelperSuccess);
							
						} else {
							completion(error, GRDVPNHelperFail);
						}
						
					} else {
						GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
					}
					return;
				}];
				return;
			}
			
			[self _oldStartIKEv2ConnectionWithCompletion:completion];
			
		} else {
			if ([self.mainCredential serverPublicKey] == nil || [self.mainCredential IPv4Address] == nil || [self.mainCredential clientId] == nil || [self.mainCredential apiAuthToken] == nil) {
				GRDErrorLogg(@"[WireGuard] Missing required credentials or server connection details. Migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
					if (completion) {
						if (success) {
							completion(nil, GRDVPNHelperSuccess);
							
						} else {
							completion(error, GRDVPNHelperFail);
						}
						
					} else {
						GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
					}
					return;
				}];
				return;
			}
			
			[self _oldStartWireGuardConnectionWithCompletion:completion];
		}
		
	}];
}

- (void)configureAndConnectVPNTunnelWithCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	__block NSUserDefaults *defaults 	= [NSUserDefaults standardUserDefaults];
	__block NSString *vpnServer 		= [defaults objectForKey:kGRDHostnameOverride];
	
	if ([defaults boolForKey:kAppNeedsSelfRepair] == YES) {
		GRDWarningLogg(@"App marked as self repair is being required. Migrating user!");
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:^(BOOL success, NSString *error) {
			if (completion) {
				if (success) {
					completion(GRDVPNHelperSuccess, nil);
					
				} else {
					completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error]);
				}
			}
			return;
		}];
		return;
	}
	
	if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO && [vpnServer hasSuffix:@".ikev2.network"] == NO) {
		GRDErrorLogg(@"Something went wrong! Bad server (%@). Migrating user...", vpnServer);
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:^(BOOL success, NSString *error) {
			if (completion) {
				if (success) {
					completion(GRDVPNHelperSuccess, nil);
					
				} else {
					completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error]);
				}
			}
			return;
		}];
		return;
	}
	
	[[GRDGatewayAPI new] getServerStatusWithCompletion:^(NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"VPN server status check failed with error: %@", errorMessage);
			[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
				if (completion) {
					if (success) {
						completion(GRDVPNHelperSuccess, nil);
						
					} else {
						completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error]);
					}
				}
				return;
			}];
			return;
		}
		
		if ([self.mainCredential transportProtocol] == TransportIKEv2) {
			NSString *apiAuthToken  = [self.mainCredential apiAuthToken];
			NSString *eapUsername   = [self.mainCredential username];
			NSData *eapPassword     = [self.mainCredential passwordRef];
			
			if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
				GRDDebugLog(@"EAP username: %@", eapUsername);
				GRDDebugLog(@"EAP password: %@", eapPassword);
				GRDDebugLog(@"EAP api auth token: %@", apiAuthToken);
				GRDErrorLogg(@"[IKEv2] Missing one or more required credentials, migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
					if (completion) {
						if (success) {
							completion(GRDVPNHelperSuccess, nil);
							
						} else {
							completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error]);
						}
					}
					return;
				}];
				return;
			}
			
			[self _startIKEv2ConnectionWithCompletion:completion];
			
		} else {
			if ([self.mainCredential serverPublicKey] == nil || [self.mainCredential IPv4Address] == nil || [self.mainCredential clientId] == nil || [self.mainCredential apiAuthToken] == nil) {
				GRDErrorLogg(@"[WireGuard] Missing required credentials or server connection details. Migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:^(BOOL success, NSString *error) {
					if (completion) {
						if (success) {
							completion(GRDVPNHelperSuccess, nil);
							
						} else {
							completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:error]);
						}
					}
					return;
				}];
				return;
			}
			
			[self _startWireGuardConnectionWithCompletion:completion];
		}
	}];
}


# pragma mark - Internal VPN Functions

/// Starting the VPN connection via the builtin IKEv2 transport protocol
- (void)_oldStartIKEv2ConnectionWithCompletion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
	if (self.tunnelLocalizedDescription == nil || [self.tunnelLocalizedDescription isEqualToString:@""]) {
		if (completion) completion(@"IKEv2 tunnel localized description missing. Please set a value for the tunnelLocalizedDescription property", GRDVPNHelperFail);
		return;
	}
	
    NEVPNManager *vpnManager = [NEVPNManager sharedManager];
    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
        if (loadError) {
            GRDErrorLogg(@"[IKEv2] Error loading NEVPNManager preferences: %@", loadError);
            if (completion) completion(@"[IKEv2] Error loading VPN configuration. Please try again.", GRDVPNHelperFail);
            return;
			
        } else {
            NSString *vpnServer = self.mainCredential.hostname;
            NSString *eapUsername = self.mainCredential.username;
            NSData *eapPassword = self.mainCredential.passwordRef;
            vpnManager.enabled = YES;
            vpnManager.protocolConfiguration = [self _prepareIKEv2ParametersForServer:vpnServer eapUsername:eapUsername eapPasswordRef:eapPassword withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
			
			NSString *finalLocalizedDescription = self.tunnelLocalizedDescription;
			if (self.appendServerRegionToTunnelLocalizedDescription == YES) {
				finalLocalizedDescription = [NSString stringWithFormat:@"%@: %@", self.tunnelLocalizedDescription, self.mainCredential.hostnameDisplayValue];
			}
			vpnManager.localizedDescription = finalLocalizedDescription;
            
			if ([self onDemand]) {
                vpnManager.onDemandEnabled = YES;
                vpnManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesWithProbeURL:!self.killSwitchEnabled];
				
            } else {
                vpnManager.onDemandEnabled = NO;
            }
			
            [vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                if (saveErr) {
                    GRDErrorLogg(@"Error saving configuration for firewall: %@", saveErr);
                    if (completion) completion(@"Error saving the VPN configuration. Please try again.", GRDVPNHelperFail);
                    return;
					
                } else {
                    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError1) {
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							[vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
								NSError *vpnErr;
								[[vpnManager connection] startVPNTunnelAndReturnError:&vpnErr];
								if (vpnErr != nil) {
									GRDErrorLogg(@"Failed to start VPN: %@", vpnErr);
									if (completion) completion(@"Error starting VPN tunnel. Please reset your connection.", GRDVPNHelperFail);
									return;
									
								} else {
									if (completion) completion(nil, GRDVPNHelperSuccess);
								}
							}];
						});
                    }];
                }
            }];
        }
    }];
}

/// Starting the VPN connection via the builtin IKEv2 transport protocol
- (void)_startIKEv2ConnectionWithCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	if (self.tunnelLocalizedDescription == nil || [self.tunnelLocalizedDescription isEqualToString:@""]) {
		if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"IKEv2 tunnel localized description missing. Please set a value for the tunnelLocalizedDescription property"]);
		return;
	}
	
	NEVPNManager *vpnManager = [NEVPNManager sharedManager];
	[vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
		if (loadError) {
			GRDErrorLogg(@"[IKEv2] Error loading NEVPNManager preferences: %@", loadError);
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[IKEv2] Error loading VPN configuration. Please try again."]);
			return;
			
		} else {
			NSString *vpnServer 				= self.mainCredential.hostname;
			NSString *eapUsername 				= self.mainCredential.username;
			NSData *eapPassword 				= self.mainCredential.passwordRef;
			vpnManager.enabled 					= YES;
			vpnManager.protocolConfiguration 	= [self _prepareIKEv2ParametersForServer:vpnServer eapUsername:eapUsername eapPasswordRef:eapPassword withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
			
			NSString *finalLocalizedDescription = self.tunnelLocalizedDescription;
			if (self.appendServerRegionToTunnelLocalizedDescription == YES) {
				finalLocalizedDescription = [NSString stringWithFormat:@"%@: %@", self.tunnelLocalizedDescription, self.mainCredential.hostnameDisplayValue];
			}
			vpnManager.localizedDescription = finalLocalizedDescription;
			
			if ([self onDemand]) {
				vpnManager.onDemandEnabled = YES;
				vpnManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesWithProbeURL:!self.killSwitchEnabled];
				
			} else {
				vpnManager.onDemandEnabled = NO;
			}
			
			[vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
				if (saveErr != nil) {
					GRDErrorLogg(@"[IKEv2] Error saving configuration for firewall: %@", saveErr);
					if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[IKEv2] Error saving the VPN configuration. Please try again."]);
					return;
					
				} else {
					[vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError1) {
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							[vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
								NSError *vpnErr;
								[[vpnManager connection] startVPNTunnelAndReturnError:&vpnErr];
								if (vpnErr != nil) {
									GRDErrorLogg(@"[IKEv2] Failed to start VPN: %@", vpnErr);
									if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[IKEv2] Error starting VPN tunnel. Please reset your connection."]);
									return;
									
								} else {
									if (completion) completion(GRDVPNHelperSuccess, nil);
								}
							}];
						});
					}];
				}
			}];
		}
	}];
}


- (NEVPNProtocolIKEv2 *)_prepareIKEv2ParametersForServer:(NSString * _Nonnull)server eapUsername:(NSString * _Nonnull)user eapPasswordRef:(NSData * _Nonnull)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType {
	NEVPNProtocolIKEv2 *protocolConfig = [[NEVPNProtocolIKEv2 alloc] init];
	protocolConfig.serverAddress = server;
	protocolConfig.serverCertificateCommonName = server;
	protocolConfig.remoteIdentifier = server;
	protocolConfig.enablePFS = YES;
	protocolConfig.disableMOBIKE = NO;
	protocolConfig.disconnectOnSleep = NO;
	protocolConfig.authenticationMethod = NEVPNIKEAuthenticationMethodCertificate; // to validate the server-side cert issued by LetsEncrypt
	protocolConfig.certificateType = certType;
	protocolConfig.useExtendedAuthentication = YES;
	protocolConfig.username = user;
	protocolConfig.passwordReference = passRef;
	protocolConfig.deadPeerDetectionRate = NEVPNIKEv2DeadPeerDetectionRateLow; /* increase DPD tolerance from default 10min to 30min */
    if (@available(iOS 14.2, *)) {
        protocolConfig.includeAllNetworks = self.killSwitchEnabled;
        protocolConfig.excludeLocalNetworks = YES;
    }
    
	NEProxySettings *proxSettings = [self proxySettings];
	if (proxSettings) {
		protocolConfig.proxySettings = proxSettings;
	}
	
	protocolConfig.useConfigurationAttributeInternalIPSubnet = NO;
#if !TARGET_OS_OSX
#if !TARGET_IPHONE_SIMULATOR
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if (@available(iOS 13.0, *)) {
		protocolConfig.enableFallback = [defaults boolForKey:kGRDWifiAssistEnableFallback];
	}
#endif
#endif
	
//  Params for VPN: AES-256, SHA-384, ECDH over the curve P-384 (DH Group 20)
//  TLS for PKI: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
	[[protocolConfig IKESecurityAssociationParameters] setEncryptionAlgorithm:NEVPNIKEv2EncryptionAlgorithmAES256];
	[[protocolConfig IKESecurityAssociationParameters] setIntegrityAlgorithm:NEVPNIKEv2IntegrityAlgorithmSHA384];
	[[protocolConfig IKESecurityAssociationParameters] setDiffieHellmanGroup:NEVPNIKEv2DiffieHellmanGroup20];
	[[protocolConfig IKESecurityAssociationParameters] setLifetimeMinutes:1440]; // 24 hours
	[[protocolConfig childSecurityAssociationParameters] setEncryptionAlgorithm:NEVPNIKEv2EncryptionAlgorithmAES256GCM];
	[[protocolConfig childSecurityAssociationParameters] setDiffieHellmanGroup:NEVPNIKEv2DiffieHellmanGroup20];
	[[protocolConfig childSecurityAssociationParameters] setLifetimeMinutes:480]; // 8 hours
	
	return protocolConfig;
}

- (NSString *)_currentDisplayHostname {
	GRDRegion *selected = [self selectedRegion];
	if (selected) {
		return selected.displayName;
		
	} else {
		return [[NSUserDefaults standardUserDefaults] valueForKey:kGRDVPNHostLocation];
	}
}

+ (NSArray *)_vpnOnDemandRulesWithProbeURL:(BOOL)probeURLEnabled {
	// RULE: connect to VPN automatically if server reports that it is running OK
	NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
	vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
	if (probeURLEnabled == YES) {
		vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/vpnsrv/api/server-status", [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride]]];
	}
	
	NSArray *onDemandArr = @[vpnServerConnectRule];
	return onDemandArr;
}

/// Starting the VPN connection via the WireGuard transport protocol with the help
/// of a NEPacketTunnelProvider instance
- (void)_oldStartWireGuardConnectionWithCompletion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
	if (self.tunnelProviderBundleIdentifier == nil ||[self.tunnelProviderBundleIdentifier isEqualToString:@""]) {
		GRDErrorLogg(@"No transport provider bundle identifier specified. Cannot start tunnel provider");
		if (completion) completion(@"No transport provider bundle identifier specified. Cannot start tunnel provider", GRDVPNHelperFail);
		return;
	
	} else if (self.grdTunnelProviderManagerLocalizedDescription == nil || [self.grdTunnelProviderManagerLocalizedDescription isEqualToString:@""]) {
		if (completion) completion(@"No localized description set for the tunnel provider description. Please set a value for the  grdTunnelProviderManagerLocalizedDescription property", GRDVPNHelperFail);
		return;
		
	} else if ([[GRDVPNHelper sharedInstance] appGroupIdentifier] == nil) {
		if (completion) completion(@"No app group identifier set. Please set a value for the appGroupIdentifier property", GRDVPNHelperFail);
		return;
	}
	
	[[GRDTunnelManager sharedManager] ensureTunnelManagerWithCompletion:^(NETunnelProviderManager * _Nullable tunnelManager, NSString * _Nullable errorMessage) {
		NSString *wireGuardConfig = [GRDWireGuardConfiguration wireguardQuickConfigForCredential:self.mainCredential dnsServers:self.preferredDNSServers];
		OSStatus saveStatus = [GRDKeychain storePassword:wireGuardConfig forAccount:kKeychainStr_WireGuardConfig];
		if (saveStatus != errSecSuccess) {
			if (completion) completion(@"Failed to store WireGuard credentials in system keychain", GRDVPNHelperFail);
			return;
		}
		
		NETunnelProviderProtocol *protocol = [NETunnelProviderProtocol new];
		protocol.serverAddress = self.mainCredential.hostname;
		protocol.providerBundleIdentifier = self.tunnelProviderBundleIdentifier;
		protocol.passwordReference = [GRDKeychain getPasswordRefForAccount:kKeychainStr_WireGuardConfig];
		protocol.username = [self.mainCredential clientId];
        
        if (@available(iOS 14.2, *)) {
            protocol.includeAllNetworks = self.killSwitchEnabled;
            protocol.excludeLocalNetworks = YES;
        }
        
		tunnelManager.protocolConfiguration = protocol;
		tunnelManager.enabled = YES;
		tunnelManager.onDemandEnabled = YES;
		tunnelManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesWithProbeURL:!self.killSwitchEnabled];

		NSString *finalDescription = self.grdTunnelProviderManagerLocalizedDescription;
		if (self.appendServerRegionToGRDTunnelProviderManagerLocalizedDescription == YES) {
			finalDescription = [NSString stringWithFormat:@"%@: %@", self.grdTunnelProviderManagerLocalizedDescription, self.mainCredential.hostnameDisplayValue];
		}
		tunnelManager.localizedDescription = finalDescription;

		[tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
			if (error != nil) {
				GRDErrorLogg(@"Failed to save packet tunnel provider manager: %@", error);
				if (completion) completion([NSString stringWithFormat:@"[WireGuard] Failed to save tunnel provider. Please try again. Error: %@", error], GRDVPNHelperFail);
				return;
			}

			[tunnelManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
				if (error != nil) {
					GRDErrorLogg(@"Failed to load packet tunnel provider manager preferences that were just saved: %@", error);
					if (completion) completion([NSString stringWithFormat:@"[WireGuard] Failed to save tunnel provider. Please try again. Error: %@", error], GRDVPNHelperFail);
					return;
				}

				NETunnelProviderSession *session = (NETunnelProviderSession*)tunnelManager.connection;
				
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
				if ([session respondsToSelector:@selector(sendProviderMessage:returnError:responseHandler:)]) {
					NSError *jsonError = nil;
					NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"wg-quick-config": wireGuardConfig} options:0 error:&jsonError];
					if (jsonError != nil) {
						if (completion) completion([NSString stringWithFormat:@"[WireGuard] Failed to JSON encode WireGuard config IPC message: %@", jsonError], GRDVPNHelperFail);
						return;
					}
					
					NSError *responseError = nil;
					[session sendProviderMessage:data returnError:&responseError responseHandler:^(NSData * _Nullable responseData) {
						if (responseError != nil) {
							GRDErrorLogg(@"Failed to send WireGuard credentials via IPC message: %@", responseError);
							if (completion) completion([NSString stringWithFormat:@"[WireGuard] Failed to send WireGuard credentials via IPC message: %@", responseError], GRDVPNHelperFail);
							return;
							
						} else if (responseData != nil) {
							NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
							GRDErrorLogg(@"Response from PTP even though it should be empty: %@", responseString);
							if (completion) completion([NSString stringWithFormat:@"[WireGuard] Response from PTP even though it should be empty: %@", responseString], GRDVPNHelperFail);
							return;
							
						} else {
							NSString *activationAttemptId = [[NSUUID UUID] UUIDString];
							GRDLogg(@"Trying to start packet tunnel provider with activation attempt uuid: %@", activationAttemptId);

							NSError *startErr;
							[session startTunnelWithOptions:@{@"activationAttemptId": activationAttemptId} andReturnError:&startErr];
							if (startErr != nil) {
								GRDErrorLogg(@"Failed to start VPN: %@", startErr);
								if (completion) completion(@"[WireGuard] Failed to start tunnel provider. Please try again", GRDVPNHelperFail);
								return;

							} else {
								if (completion) completion(nil, GRDVPNHelperSuccess);
							}
						}
					}];
				}
				
#elif TARGET_OS_IPHONE
				NSString *activationAttemptId = [[NSUUID UUID] UUIDString];
				GRDLogg(@"Trying to start packet tunnel provider with activation attempt uuid: %@", activationAttemptId);

				NSError *startErr;
				[session startTunnelWithOptions:@{@"activationAttemptId": activationAttemptId} andReturnError:&startErr];
				if (startErr != nil) {
					GRDErrorLogg(@"Failed to start VPN: %@", startErr);
					if (completion) completion(@"[WireGuard] Failed to start tunnel provider. Please try again", GRDVPNHelperFail);
					return;

				} else {
					if (completion) completion(nil, GRDVPNHelperSuccess);
				}
#endif
			}];
		}];
	}];
}

/// Starting the VPN connection via the WireGuard transport protocol with the help
/// of a NEPacketTunnelProvider instance
- (void)_startWireGuardConnectionWithCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	if (self.tunnelProviderBundleIdentifier == nil ||[self.tunnelProviderBundleIdentifier isEqualToString:@""]) {
		GRDErrorLogg(@"[GRDTunnel] No transport provider bundle identifier specified. Cannot start tunnel provider");
		if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] No transport provider bundle identifier specified. Cannot start tunnel provider"]);
		return;
		
	} else if (self.grdTunnelProviderManagerLocalizedDescription == nil || [self.grdTunnelProviderManagerLocalizedDescription isEqualToString:@""]) {
		if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] No localized description set for the tunnel provider description. Please set a value for the  grdTunnelProviderManagerLocalizedDescription property"]);
		return;
		
	} else if ([[GRDVPNHelper sharedInstance] appGroupIdentifier] == nil) {
		if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] No app group identifier set. Please set a value for the appGroupIdentifier property"]);
		return;
	}
	
	[[GRDTunnelManager sharedManager] ensureTunnelManagerWithCompletion:^(NETunnelProviderManager * _Nullable tunnelManager, NSString * _Nullable errorMessage) {
		NSString *wireGuardConfig = [GRDWireGuardConfiguration wireguardQuickConfigForCredential:self.mainCredential dnsServers:self.preferredDNSServers];
		OSStatus saveStatus = [GRDKeychain storePassword:wireGuardConfig forAccount:kKeychainStr_WireGuardConfig];
		if (saveStatus != errSecSuccess) {
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] Failed to store WireGuard credentials in system keychain"]);
			return;
		}
		
		NETunnelProviderProtocol *protocol = [NETunnelProviderProtocol new];
		protocol.serverAddress = self.mainCredential.hostname;
		protocol.providerBundleIdentifier = self.tunnelProviderBundleIdentifier;
		protocol.passwordReference = [GRDKeychain getPasswordRefForAccount:kKeychainStr_WireGuardConfig];
		protocol.username = [self.mainCredential clientId];
		
		if (@available(iOS 14.2, *)) {
			protocol.includeAllNetworks = self.killSwitchEnabled;
			protocol.excludeLocalNetworks = YES;
		}
		
		tunnelManager.protocolConfiguration = protocol;
		tunnelManager.enabled = YES;
		tunnelManager.onDemandEnabled = YES;
		tunnelManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesWithProbeURL:!self.killSwitchEnabled];
		
		NSString *finalDescription = self.grdTunnelProviderManagerLocalizedDescription;
		if (self.appendServerRegionToGRDTunnelProviderManagerLocalizedDescription == YES) {
			finalDescription = [NSString stringWithFormat:@"%@: %@", self.grdTunnelProviderManagerLocalizedDescription, self.mainCredential.hostnameDisplayValue];
		}
		tunnelManager.localizedDescription = finalDescription;
		
		[tunnelManager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
			if (error != nil) {
				GRDErrorLogg(@"[GRDTunnel] Failed to save packet tunnel provider manager: %@", error);
				if (completion) completion(GRDVPNHelperFail, error);
				return;
			}
			
			[tunnelManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
				if (error != nil) {
					GRDErrorLogg(@"[GRDTunnel] Failed to load packet tunnel provider manager preferences that were just saved: %@", error);
					if (completion) completion(GRDVPNHelperFail, error);
					return;
				}
				
				NETunnelProviderSession *session = (NETunnelProviderSession*)tunnelManager.connection;
				
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
				if ([session respondsToSelector:@selector(sendProviderMessage:returnError:responseHandler:)]) {
					NSError *jsonError = nil;
					NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"wg-quick-config": wireGuardConfig} options:0 error:&jsonError];
					if (jsonError != nil) {
						if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"[GRDTunnel] Failed to JSON encode WireGuard config IPC message: %@", jsonError]]);
						return;
					}
					
					NSError *responseError = nil;
					[session sendProviderMessage:data returnError:&responseError responseHandler:^(NSData * _Nullable responseData) {
						if (responseError != nil) {
							GRDErrorLogg(@"[GRDTunnel] Failed to send WireGuard credentials via IPC message: %@", responseError);
							if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"[GRDTunnel] Failed to send WireGuard credentials via IPC message: %@", responseError]]);
							return;
							
						} else if (responseData != nil) {
							NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
							GRDErrorLogg(@"[GRDTunnel] Response from PTP even though it should be empty: %@", responseString);
							if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"[GRDTunnel] Response from PTP even though it should be empty: %@", responseString]]);
							return;
							
						} else {
							NSString *activationAttemptId = [[NSUUID UUID] UUIDString];
							GRDWarningLogg(@"[GRDTunnel] Trying to start packet tunnel provider with activation attempt uuid: %@", activationAttemptId);
							
							NSError *startErr;
							[session startTunnelWithOptions:@{@"activationAttemptId": activationAttemptId} andReturnError:&startErr];
							if (startErr != nil) {
								GRDErrorLogg(@"[GRDTunnel] Failed to start VPN: %@", startErr);
								if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] Failed to start tunnel provider. Please try again"]);
								return;
								
							} else {
								if (completion) completion(GRDVPNHelperSuccess, nil);
							}
						}
					}];
				}
				
#elif TARGET_OS_IPHONE
				NSString *activationAttemptId = [[NSUUID UUID] UUIDString];
				GRDWarningLogg(@"[GRDTunnel] Trying to start packet tunnel provider with activation attempt uuid: %@", activationAttemptId);
				
				NSError *startErr;
				[session startTunnelWithOptions:@{@"activationAttemptId": activationAttemptId} andReturnError:&startErr];
				if (startErr != nil) {
					GRDErrorLogg(@"[GRDTunnel] Failed to start VPN: %@", startErr);
					if (completion) completion(GRDVPNHelperFail, startErr);
					return;
					
				} else {
					if (completion) completion(GRDVPNHelperSuccess, nil);
				}
#endif
			}];
		}];
	}];
}

- (void)disconnectVPN {
	NEVPNManager *vpnManager = [NEVPNManager sharedManager];
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	
	if (vpnManager.enabled == YES) {
		GRDLogg(@"Disconnecting IKEv2 VPN");
		// Note from CJ 2022-02-23:
		// You may think that we do not want to disable the VPN profile
		// but as it turns out we are triggering some other bananas bug with the
		// WireGuard integration which means that if it's not set to enable == NO
		// the IKEv2 connection after switching protocols from WireGuard -> IKEv2
		// will get stuck in a connection loop
		[vpnManager setEnabled:NO];
		[vpnManager setOnDemandEnabled:NO];
		[vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
			if (saveErr) {
				GRDErrorLogg(@"Error saving update for firewall config: %@", saveErr);
			}
			
			[[vpnManager connection] stopVPNTunnel];
		}];
	}
	
	if (tunnelManager.enabled == YES) {
		GRDLogg(@"Disconnecting WireGuard VPN");
		// Note from CJ 2022-02-22:
		// This is a complete and utter hack that took
		// me 9 hours to track and down and finess.
		// The first one to touch this without explicit approval
		// will die a painful death and yes this is a threat.
		// If you break this I will come and murder you and your family
		[tunnelManager setEnabled:NO];
		[tunnelManager setOnDemandEnabled:NO];
        
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
		[tunnelManager setOnDemandRules:@[]];
		[tunnelManager setProtocolConfiguration:nil];
		[tunnelManager removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
			if (error != nil) {
				GRDWarningLogg(@"Failed to delete prefs: %@", [error localizedDescription]);
			}
		}];
        [(NETunnelProviderSession *)tunnelManager.connection stopTunnel];

#else
        [tunnelManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
            if (saveErr) {
                GRDErrorLogg(@"Error saving update for firewall config: %@", saveErr);
            }
            
            [(NETunnelProviderSession *)tunnelManager.connection stopVPNTunnel];
        }];
#endif
	}
}

- (void)disconnectVPNWithCompletion:(void (^)(NSError * _Nullable))completion {
	NEVPNManager *vpnManager = [NEVPNManager sharedManager];
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	
	if (vpnManager.enabled == YES) {
		GRDLogg(@"Disconnecting IKEv2 VPN");
		// Note from CJ 2022-02-23:
		// You may think that we do not want to disable the VPN profile
		// but as it turns out we are triggering some other bananas bug with the
		// WireGuard integration which means that if it's not set to enable == NO
		// the IKEv2 connection after switching protocols from WireGuard -> IKEv2
		// will get stuck in a connection loop
		[vpnManager setEnabled:NO];
		[vpnManager setOnDemandEnabled:NO];
		[vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
			[[vpnManager connection] stopVPNTunnel];
			if (completion) completion(saveErr);
		}];
	}
	
	if (tunnelManager.enabled == YES) {
		GRDLogg(@"Disconnecting WireGuard VPN");
		// Note from CJ 2022-02-22:
		// This is a complete and utter hack that took
		// me 9 hours to track and down and finess.
		// The first one to touch this without explicit approval
		// will die a painful death
		[tunnelManager setEnabled:NO];
		[tunnelManager setOnDemandEnabled:NO];
		
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
		[tunnelManager setOnDemandRules:@[]];
		[tunnelManager setProtocolConfiguration:nil];
		[tunnelManager removeFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
			if (error != nil) {
				if (completion) completion(error);
			}
		}];
		// Note from CJ 2023-02-20
		// It may seems as though we'd want the line below in the completion handler from removeFromPreferencesWithCompletionHandler
		// but if I recall correctly, this was done this was specifically to thread the needle on the race condition within
		// the NetworkExtension.framework to actually be able to disconnect the WireGuard connection successfully
		// This might seem very dangerous but should remain as is for now
		[(NETunnelProviderSession *)tunnelManager.connection stopTunnel];
		if (completion) completion(nil);
		
#else
		[tunnelManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
			[(NETunnelProviderSession *)tunnelManager.connection stopVPNTunnel];
			if (completion) completion(saveErr);
		}];
#endif
	}
}

- (void)forceDisconnectVPNIfNecessary {
	__block NEVPNStatus ikev2Status = [[[NEVPNManager sharedManager] connection] status];
	if (ikev2Status == NEVPNStatusConnected || ikev2Status == NEVPNStatusConnecting) {
		[self disconnectVPN];

	} else if (ikev2Status == NEVPNStatusInvalid || ikev2Status == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			ikev2Status = [[[NEVPNManager sharedManager] connection] status];
			if (ikev2Status == NEVPNStatusConnected) {
				[self disconnectVPN];
			}
		});
	}
	
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	__block NEVPNStatus wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
	if (wireguardStatus == NEVPNStatusConnected || wireguardStatus == NEVPNStatusConnecting) {
		[self disconnectVPN];

	} else if (wireguardStatus == NEVPNStatusInvalid || wireguardStatus == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
			if (wireguardStatus == NEVPNStatusConnected) {
				[self disconnectVPN];
			}
		});
	}
	
	// Blocking the thread for one second to allow everything else
	// to catch up as the NEVPN... API have the potential to be slow
	// This way we can prevent any network race conditions in other
	// API calls
	sleep(1);
}


# pragma mark - Credential Creation Helper

- (void)getValidSubscriberCredentialWithCompletion:(void (^)(GRDSubscriberCredential * _Nullable subscriberCredential, NSString * _Nullable errorMessage))completion {
	// Note from CJ 2023-03-29
	// This has been a little nonsensical in the current state
//	if (![GRDSubscriptionManager isPayingUser]) {
//		if (completion) {
//			completion(nil, @"A paid account is required to create a subscriber credential.");
//			return;
//		}
//	}
	
	// Use convenience method to get access to our current subscriber cred (if it exists)
	GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
	BOOL expired = [subCred tokenExpired];
	// check current Subscriber Credential if it exists
	if (expired == YES || subCred == nil) {
		// No subscriber credential yet or it is expired. We have to create a new one
		GRDWarningLog(@"No subscriber credential present or it has passed the safe expiration point");
		
		// Default to AppStore Receipt
		GRDHousekeepingValidationMethod valmethod = ValidationMethodAppStoreReceipt;
		NSMutableDictionary *customKeys = [NSMutableDictionary new];
		
		// Check to see if we have a PEToken
		NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
		if (petToken.length > 0) {
			valmethod = ValidationMethodPEToken;
		
		} else if (self.customSubscriberCredentialAuthKeys != nil) {
			valmethod = ValidationMethodCustom;
			customKeys = self.customSubscriberCredentialAuthKeys;
		}
		
		[[GRDHousekeepingAPI new] createSubscriberCredentialForBundleId:[[NSBundle mainBundle] bundleIdentifier] withValidationMethod:valmethod customKeys:customKeys completion:^(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage) {
			if (success == NO && errorMessage != nil) {
				if (completion) {
					completion(nil, errorMessage);
				}
				return;
				
			} else if (success == YES) {
				[GRDKeychain removeSubscriberCredentialWithRetries:3];
				OSStatus saveStatus = [GRDKeychain storePassword:subscriberCredential forAccount:kKeychainStr_SubscriberCredential];
				if (saveStatus != errSecSuccess) {
					if (completion) {
						completion(nil, @"Couldn't save subscriber credential in local keychain. Please try again.");
					}
					return;
				}
				
				GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subscriberCredential];
				GRDDebugLog(@"Successfully stored new Subscriber Credential: %@", subscriberCredential);
				if (completion) {
					completion(subCred, nil);
				}
			}
		}];
		
	} else {
		GRDDebugLog(@"Valid Subscriber Credential found: %@", subCred.jwt);
		if (completion) {
			completion(subCred, nil);
		}
	}
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))completion {
    [self createStandaloneCredentialsForDays:validForDays hostname:[[NSUserDefaults standardUserDefaults]valueForKey:kGRDHostnameOverride] completion:completion];
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * creds, NSString * errorMessage))completion {
    [self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential *subscriberCredential, NSString *error) {
        if (subscriberCredential != nil) {
            NSInteger adjustedDays = [GRDVPNHelper _subCredentialDays];
            //adjust the day count in case 30 is too many
            [[GRDGatewayAPI new] registerAndCreateWithHostname:hostname subscriberCredential:subscriberCredential.jwt validForDays:adjustedDays completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
                if (success == NO && errorMessage != nil) {
                    completion(nil, errorMessage);
                    
                } else {
                    completion(credentials, nil);
                }
            }];
            
        } else {
            completion(nil,error);
        }
    }];
}

- (void)createStandaloneCredentialsForTransportProtocol:(TransportProtocol)protocol days:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))completion {
	[self createStandaloneCredentialsForTransportProtocol:protocol validForDays:validForDays hostname:[[NSUserDefaults standardUserDefaults]valueForKey:kGRDHostnameOverride] completion:completion];
}

- (void)createStandaloneCredentialsForTransportProtocol:(TransportProtocol)protocol validForDays:(NSInteger)days hostname:(NSString *)hostname completion:(void (^)(NSDictionary * credentials, NSString * errorMessage))completion {
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential *subscriberCredential, NSString *error) {
		if (subscriberCredential != nil) {
			NSInteger adjustedDays = [GRDVPNHelper _subCredentialDays];
			//adjust the day count in case 30 is too many

			if (protocol == TransportIKEv2) {
				[[GRDGatewayAPI new] registerDeviceForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:hostname subscriberCredential:subscriberCredential.jwt validForDays:adjustedDays transportOptions:@{} completion:^(NSDictionary * _Nullable credentialDetails, BOOL success, NSString * _Nullable errorMessage) {
					if (success == NO && errorMessage != nil) {
						completion(nil, errorMessage);

					} else {
						completion(credentialDetails, nil);
					}
				}];
				
			} else {
				GRDCurve25519 *keys = [[GRDCurve25519 alloc] init];
				[keys generateKeyPair];
				
				[[GRDGatewayAPI new] registerDeviceForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:hostname subscriberCredential:subscriberCredential.jwt validForDays:adjustedDays transportOptions:@{@"public-key":keys.publicKey} completion:^(NSDictionary * _Nullable credentialDetails, BOOL success, NSString * _Nullable errorMessage) {
					if (success == NO && errorMessage != nil) {
						if (completion) completion(nil, errorMessage);
						return;
						
					} else {
						NSMutableDictionary *newDict = [credentialDetails mutableCopy];
						[newDict setObject:keys.privateKey forKey:kGRDWGDevicePrivateKey];
						[newDict setObject:keys.publicKey forKey:kGRDWGDevicePublicKey];
						
						if (completion) completion(newDict, nil);
					}
				}];
			}
						
		} else {
			completion(nil, error);
		}
	}];
}

+ (NSInteger)_subCredentialDays {
	NSInteger eapCredentialsValidFor = 30;
	GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:[GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential]];
	if (!subCred) {
		GRDWarningLogg(@"No Subscriber Credential present");
	}
	
	// Note from CJ 2020-11-24
	// This is incredibly primitive and will be improved soon
	// Note from CJ 2021-11-01
	// This was a lie
	if ([subCred.subscriptionType isEqualToString:kGuardianFreeTrial3Days]) {
		eapCredentialsValidFor = 3;
	}
	return eapCredentialsValidFor;
}

# pragma mark - Credential Validation Helper

- (void)verifyMainEAPCredentialsWithCompletion:(void(^)(BOOL valid, NSString * _Nullable errorMessage))completion {
    GRDCredential *mainCreds = [GRDCredentialManager mainCredentials];
    if (!mainCreds) {
        if (completion) completion(NO, @"No main EAP Credentials found");
		return;
	}
	
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential * _Nullable subscriberCredential, NSString * _Nullable error) {
		if (error != nil) {
			if (completion) completion(NO, error);
			return;
		}
		
		[[GRDGatewayAPI new] verifyEAPCredentialsUsername:mainCreds.username apiToken:mainCreds.apiAuthToken andSubscriberCredential:subscriberCredential.jwt forVPNNode:mainCreds.hostname completion:^(BOOL success, BOOL stillValid, NSString * _Nullable errorMessage, BOOL subCredInvalid) {
			if (success) {
				if (subCredInvalid) { //if this is invalid, remove it regardless of anything else.
					[GRDKeychain removeSubscriberCredentialWithRetries:3];
				}
				
				if (stillValid == YES) {
					if (completion) completion(YES, nil);
					return;
					
				} else { //successful API return, EAP creds are currently invalid.
					if ([self isConnected] == NO) {
						[self forceDisconnectVPNIfNecessary];
						//create a fresh set of credentials (new user) in our current region.
						[self configureFirstTimeUserWithRegion:self.selectedRegion completion:^(BOOL success, NSString * _Nullable errorMessage) {
							if (completion) {
								completion(success, errorMessage);
							}
						}];
					}
				}
				
			} else { //success is NO
				if (completion) {
					completion(NO, errorMessage);
				}
			}
		}];
	}];
}

- (void)verifyMainCredentialsWithCompletion:(void(^)(BOOL valid, NSString * _Nullable errorMessage))completion {
	GRDCredential *mainCreds = [GRDCredentialManager mainCredentials];
	if (mainCreds == nil) {
		if (completion) completion(NO, @"No VPN credentials found");
		return;
	}
	
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential * _Nullable subscriberCredential, NSString * _Nullable error) {
		if (error != nil) {
			if (completion) completion(NO, error);
			return;
		}
		
		GRDGatewayAPI *gatewayAPI = [GRDGatewayAPI new];
		[gatewayAPI verifyCredentialsForClientId:mainCreds.clientId withAPIToken:mainCreds.apiAuthToken hostname:mainCreds.hostname subscriberCredential:subscriberCredential.jwt completion:^(BOOL success, BOOL credentialsValid, NSString * _Nullable errorMessage) {
			if (success == YES) {
				if (credentialsValid == YES) {
					if (completion) completion(YES, nil);
					return;
				
				} else {
					if ([self isConnected] == NO) {
						[self forceDisconnectVPNIfNecessary];
						//create a fresh set of credentials (new user) in our current region.
						[self configureFirstTimeUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withRegion:self.selectedRegion completion:^(BOOL success, NSString * _Nullable errorMessage) {
							if (completion) completion(success, errorMessage);
							return;
						}];
					
					} else {
						if (completion) completion(NO, errorMessage);
						return;
					}
				}
				
			} else {
				if ([self isConnected] == NO) {
					[self forceDisconnectVPNIfNecessary];
					//create a fresh set of credentials (new user) in our current region.
					[self configureFirstTimeUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withRegion:self.selectedRegion completion:^(BOOL success, NSString * _Nullable errorMessage) {
						if (completion) completion(success, errorMessage);
						return;
					}];
				
				} else {
					if (completion) completion(NO, errorMessage);
					return;
				}
			}
		}];
	}];
}

# pragma mark - Migration Helper

- (void)migrateUserWithCompletion:(void (^_Nullable)(BOOL success, NSString *error))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:_featureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSError * _Nullable errorMessage) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (errorMessage != nil) {
				if (completion) {
					completion(NO, [errorMessage localizedDescription]);
				}
				
			} else {
				[self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation postCredential:nil completion:completion];
			}
		});
	}];
}

- (void)migrateUserForTransportProtocol:(TransportProtocol)protocol withCompletion:(void (^_Nullable)(BOOL success, NSString *error))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:_featureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(NO, [errorMessage localizedDescription]);
			return;
		}
		
		[self configureFirstTimeUserForTransportProtocol:protocol hostname:guardianHost andHostLocation:guardianHostLocation postCredential:nil completion:completion];
	}];
}

- (void)selectRegion:(GRDRegion * _Nullable)selectedRegion {
	_selectedRegion = selectedRegion;
	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
	if (selectedRegion != nil && selectedRegion.isAutomatic == NO) {
		[def setBool:YES forKey:kGuardianUseFauxTimeZone];
		[def setObject:selectedRegion.regionName forKey:kGuardianFauxTimeZone];
		[def setObject:selectedRegion.displayName forKey:kGuardianFauxTimeZonePretty];
		
	} else {
		//resetting the value to nil, (Automatic)
		GRDLogg(@"Automatic region selection selected. Resetting all faux values");
		_selectedRegion = nil;
		[def removeObjectForKey:kGRDHostnameOverride];
		[def removeObjectForKey:kGRDVPNHostLocation];
		[def setBool:NO forKey:kGuardianUseFauxTimeZone];
		[def removeObjectForKey:kGuardianFauxTimeZone];
		[def removeObjectForKey:kGuardianFauxTimeZonePretty];
	}
}



- (void)clearLocalCache {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// Note from CJ 2021-10-28:
	// Nodes should no longer be locally cached so this should be
	// remove all together soon
	[defaults removeObjectForKey:kKnownGuardianHosts];
	[defaults removeObjectForKey:housekeepingTimezonesTimestamp];
	[defaults removeObjectForKey:kKnownHousekeepingTimeZonesForRegions];
	[defaults removeObjectForKey:kGuardianAllRegions];
	[defaults removeObjectForKey:kGuardianAllRegionsTimeStamp];
	[defaults removeObjectForKey:kGRDEAPSharedHostname];
	[GRDKeychain removeGuardianKeychainItems];
	[GRDKeychain removeSubscriberCredentialWithRetries:3];
}

@end
