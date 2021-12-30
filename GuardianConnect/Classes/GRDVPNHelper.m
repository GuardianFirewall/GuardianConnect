//
//  GRDVPNHelper.m
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/EXTScope.h>

@import UserNotifications;

@implementation GRDVPNHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GRDVPNHelper *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GRDVPNHelper alloc] init];
        shared.onDemand = true;
        [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                shared.vpnLoaded = false;
                shared.lastErrorMessage = error.localizedDescription;
				
            } else {
                shared.vpnLoaded = true;
            }
        }];
        [shared _loadCredentialsFromKeychain]; //the API user shouldn't have to call this manually, been meaning to put this in here.
    });
    return shared;
}

+ (BOOL)activeConnectionPossible {
    GRDCredential *cred = [GRDCredentialManager mainCredentials];
    NSString *apiHostname = cred.hostname;
    NSString *authToken = cred.apiAuthToken;
    NSString *eapUsername = cred.username;
    if (apiHostname == nil || authToken == nil || eapUsername == nil) return false;
    return true;
}

+ (void)saveAllInOneBoxHostname:(NSString *)host {
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kGRDHostnameOverride];
}

+ (void)clearVpnConfiguration {
    GRDCredential *creds = [GRDCredentialManager mainCredentials];
    NSString *eapUsername = [creds username];
    NSString *apiAuthToken = [creds apiAuthToken];
    
    [[GRDGatewayAPI new] invalidateEAPCredentials:eapUsername andAPIToken:apiAuthToken completion:^(BOOL success, NSString * _Nullable errorMessage) {
        if (success == NO) {
            GRDLog(@"Failed to invalidate EAP credentials: %@", errorMessage);
        }
    }];
    
    [GRDKeychain removeGuardianKeychainItems];
    [GRDCredentialManager clearMainCredentials];
    [[GRDVPNHelper sharedInstance] setMainCredential:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kGRDHostnameOverride];
    [defaults removeObjectForKey:kGRDVPNHostLocation];
    [defaults removeObjectForKey:housekeepingTimezonesTimestamp];
    [defaults setBool:NO forKey:kAppNeedsSelfRepair];
    
    
    // make sure Settings tab UI updates to not erroneously show name of cleared server
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}

+ (NSArray *)vpnOnDemandRules {
    // RULE: connect to VPN automatically if server reports that it is running OK
    NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
    vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
    vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride], kSGAPI_ServerStatus]];
    
    NSArray *onDemandArr = @[vpnServerConnectRule];
    return onDemandArr;
}

- (NEVPNProtocolIKEv2 *)prepareIKEv2ParametersForServer:(NSString * _Nonnull)server eapUsername:(NSString * _Nonnull)user eapPasswordRef:(NSData * _Nonnull)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType {
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
    NEProxySettings *proxSettings = [self proxySettings];
    if (proxSettings) {
        protocolConfig.proxySettings = proxSettings;
    }
    
    protocolConfig.useConfigurationAttributeInternalIPSubnet = false;
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

- (void)forceDisconnectVPNIfNecessary {
    __block NEVPNStatus currentStatus = [[[NEVPNManager sharedManager] connection] status];
    if (currentStatus == NEVPNStatusConnected) {
        [self disconnectVPN];

    } else if (currentStatus == NEVPNStatusInvalid) { //if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            currentStatus = [[[NEVPNManager sharedManager] connection] status];
            if (currentStatus == NEVPNStatusConnected) {
                [self disconnectVPN];
            }
        });
    }
}

- (void)disconnectVPN {
    NEVPNManager *vpnManager = [NEVPNManager sharedManager];
    [vpnManager setEnabled:NO];
    [vpnManager setOnDemandEnabled:NO];
    [vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
        if (saveErr) {
            NSLog(@"[DEBUG][disconnectVPN] error saving update for firewall config = %@", saveErr);
            [[vpnManager connection] stopVPNTunnel];
			
        } else {
            [[vpnManager connection] stopVPNTunnel];
        }
    }];
}

+ (NSInteger)subCredentialDays {
    NSInteger eapCredentialsValidFor = 30;
    GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:[GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential]];
    if (!subCred) {
        GRDLog(@"[DEBUG] this is probably bad!!");
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

- (void)migrateUserWithCompletion:(void (^_Nullable)(BOOL success, NSString *error))completion {
    GRDServerManager *serverManager = [[GRDServerManager alloc] init];
    [serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorMessage != nil) {
                if (completion) {
                    completion(false, errorMessage);
                }
                
            } else {
                [self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation completion:completion];
            }
        });
    }];
}

- (void)selectRegion:(GRDRegion * _Nullable)selectedRegion {
    _selectedRegion = selectedRegion;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (selectedRegion) {
        [def setBool:true forKey:kGuardianUseFauxTimeZone];
        [def setObject:selectedRegion.regionName forKey:kGuardianFauxTimeZone];
        [def setObject:selectedRegion.displayName forKey:kGuardianFauxTimeZonePretty];
        
    } else {
        //resetting the value to nil, (Automatic)
        [def setBool:false forKey:kGuardianUseFauxTimeZone];
        [def removeObjectForKey:kGuardianFauxTimeZone];
        [def removeObjectForKey:kGuardianFauxTimeZonePretty];
    }
}

/// retrieves values out of the system keychain and stores them in the sharedAPI singleton object in memory for other functions to use in the future
- (void)_loadCredentialsFromKeychain {
    [self setMainCredential:[GRDCredentialManager mainCredentials]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kGuardianUseFauxTimeZone]) {
        GRDRegion *region = [[GRDRegion alloc] init];
        region.regionName = [defaults valueForKey:kGuardianFauxTimeZone];
        region.displayName = [defaults valueForKey:kGuardianFauxTimeZonePretty];
        _selectedRegion = region;
        [self validateCurrentEAPCredentialsWithCompletion:^(BOOL valid, NSString * _Nullable errorMessage) {
            // This is called upon app load in the background and the method already tries to recreate the credentials,
            // if it returns a failure, trying to create new ones failed & there isnt much else that can be done.
            // just log an error for now.
			// Definitely should not surface any error alerts to the user.
            if (!valid) {
                GRDLog(@"Credentials are invalid and failed to re-create: %@", errorMessage);
            }
        }];
    }
}

- (NSString *)currentDisplayHostname {
    GRDRegion *selected = [self selectedRegion];
    if (selected) {
        return selected.displayName;
        
    } else {
        return [[NSUserDefaults standardUserDefaults] valueForKey:kGRDVPNHostLocation];
    }
}

//trying to make configureAndConnectVPNWithCompletion a bit smaller and more manageable, DONT CALL DIRECTLY.
- (void)_createVPNConnectionWithCompletion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
    NEVPNManager *vpnManager = [NEVPNManager sharedManager];
    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
        if (loadError) {
            GRDLog(@"Error loading prefs = %@", loadError);
            if (completion) completion(@"Error loading VPN configuration. Please try again.", GRDVPNHelperFail);
            return;
			
        } else {
            NSString *vpnServer = self.mainCredential.hostname;
            NSString *eapUsername = self.mainCredential.username;
            NSData *eapPassword = self.mainCredential.passwordRef;
            vpnManager.enabled = YES;
            vpnManager.protocolConfiguration = [self prepareIKEv2ParametersForServer:vpnServer eapUsername:eapUsername eapPasswordRef:eapPassword withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
            vpnManager.localizedDescription = [NSString stringWithFormat:@"Guardian Firewall: %@", [self currentDisplayHostname]];
            
			if ([self onDemand]) {
                vpnManager.onDemandEnabled = YES;
                vpnManager.onDemandRules = [GRDVPNHelper vpnOnDemandRules];
				
            } else {
                vpnManager.onDemandEnabled = NO;
            }
			
            [vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                if (saveErr) {
                    GRDLog(@"Error saving configuration for firewall = %@", saveErr);
                    if (completion) completion(@"Error saving the VPN configuration. Please try again.", GRDVPNHelperFail);
                    return;
					
                } else {
                    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError1) {
                        [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                            NSError *vpnErr;
                            [[vpnManager connection] startVPNTunnelAndReturnError:&vpnErr];
                            if (vpnErr != nil) {
                                GRDLog(@"Failed to start VPN: %@", vpnErr);
                                if (completion) completion(@"Error starting VPN tunnel. Please reset your connection.", GRDVPNHelperFail);
                                return;
								
                            } else {
                                [[GRDGatewayAPI new] startHealthCheckTimer];
                                if (completion) completion(nil, GRDVPNHelperSuccess);
                            }
                        }];
                    }];
                }
            }];
        }
    }];
}

- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString * _Nullable error, GRDVPNHelperStatusCode statusCode))completion {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    __block NSString *vpnServer = [defaults objectForKey:kGRDHostnameOverride];
    
    if ([defaults boolForKey:kAppNeedsSelfRepair] == YES) {
        GRDLog(@"App marked as self repair is being required. Migrating user!");
        [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
            if (completion) {
                if (success) {
                    completion(nil, GRDVPNHelperSuccess);
                    
                } else {
                    completion(error, GRDVPNHelperFail);
                }
                
            } else {
                GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
            }
        }];
        return;
    }
    
    if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO && [vpnServer hasSuffix:@".ikev2.network"] == NO) {
        GRDLog(@"[DEBUG] something went wrong! bad server (%@). Migrating user...", vpnServer);
        [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
            if (completion) {
                if (success) {
                    completion(nil, GRDVPNHelperSuccess);
                    
                } else {
                    completion(error, GRDVPNHelperFail);
                }
                
            } else {
				GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
            }
        }];
        return;
    }
    
    [[GRDGatewayAPI new] getServerStatusWithCompletion:^(GRDGatewayAPIResponse *apiResponse) {
        if (apiResponse.responseStatus == GRDGatewayAPIServerOK) {
            NSString *apiAuthToken  = [self.mainCredential apiAuthToken];
            NSString *eapUsername   = [self.mainCredential username];
            NSData *eapPassword     = [self.mainCredential passwordRef];
            
            if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
                GRDLog(@"Missing required credentials, migrating!");
                [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                    if (completion) {
                        if (success) {
                            completion(nil, GRDVPNHelperSuccess);
                            
                        } else {
                            completion(error, GRDVPNHelperFail);
                        }
                        
                    } else {
						GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
                    }
                }];
                return;
            }
            
            [self _createVPNConnectionWithCompletion:completion];
            
        } else if (apiResponse.responseStatus == GRDGatewayAPIServerInternalError || apiResponse.responseStatus == GRDGatewayAPIServerNotOK) {
            NSMutableArray *knownHostnames = [NSMutableArray arrayWithArray:[defaults objectForKey:kKnownGuardianHosts]];
            for (int i = 0; i < [knownHostnames count]; i++) {
                NSDictionary *serverObject = [knownHostnames objectAtIndex:i];
                if ([[serverObject objectForKey:@"hostname"] isEqualToString:vpnServer]) {
                    [knownHostnames removeObject:serverObject];
                }
            }
            
            [defaults setObject:[NSArray arrayWithArray:knownHostnames] forKey:kKnownGuardianHosts];
            [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                if (completion){
                    if (success){
                        completion(nil, GRDVPNHelperSuccess);
                    } else {
                        completion(error, GRDVPNHelperFail);
                    }
                } else {
					GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
                }
            }];
            return;
            
        } else if (apiResponse.responseStatus == GRDGatewayAPIUnknownError) {
            if (apiResponse.error.code == NSURLErrorTimedOut || apiResponse.error.code == NSURLErrorServerCertificateHasBadDate || apiResponse.error.code == GRDVPNHelperDoesNeedMigration) {
                GRDErrorLogg(@"Timeout error! Cert expiration error or host not found, migrating!");
                [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                    if (completion) {
                        if (success) {
                            completion(nil, GRDVPNHelperSuccess);
							
                        } else {
                            completion(error, GRDVPNHelperFail);
                        }
                    } else {
						GRDErrorLogg(@"No COMPLETION BLOCK SET! Going to have a bad time");
                    }
                }];
				
            } else {
				GRDErrorLogg(@"Failed to connect to host: %@", [apiResponse.error localizedDescription]);
                if (completion) completion(@"Unknown error occured. Please try again soon", GRDVPNHelperFail);
            }
        }
    }];
}

- (void)getValidSubscriberCredentialWithCompletion:(void (^)(NSString * _Nullable credential, NSString * _Nullable errorMessage))completion {
    if (![GRDSubscriptionManager isPayingUser]) {
        if (completion) {
            completion(nil, @"A paid account is required to create a subscriber credential.");
            return;
        }
    }
    
    // Use convenience method to get access to our current subscriber cred (if it exists)
    GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
    __block NSString *subCredString = subCred.subscriberCredential;

    // create a fresh new credential
    if ([subCred tokenExpired] || subCred == nil) {
        // No subscriber credential yet or it is expired. We have to create a new one
        GRDDebugLog(@"No subscriber credential present or it has passed the safe expiration point");
        
        // Default to AppStore Receipt now since we don't have a free tier anymore.
        GRDHousekeepingValidationMethod valmethod = ValidationMethodAppStoreReceipt;
        
        // Check to see if we have a PEToken
        NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
        if (petToken.length > 0) {
            valmethod = ValidationmethodPEToken;
        }
        
        [[GRDHousekeepingAPI new] createNewSubscriberCredentialWithValidationMethod:valmethod completion:^(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage) {
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
                
                completion(subscriberCredential, nil);
            }
        }];
        
    } else {
        if (completion) {
            completion(subCredString, nil);
        }
    }
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))completion {
    [self createStandaloneCredentialsForDays:validForDays hostname:[[NSUserDefaults standardUserDefaults]valueForKey:kGRDHostnameOverride] completion:completion];
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * creds, NSString * errorMessage))completion {
    [self getValidSubscriberCredentialWithCompletion:^(NSString *credential, NSString *error) {
        if (credential != nil) {
            NSInteger adjustedDays = [GRDVPNHelper subCredentialDays];
            //adjust the day count in case 30 is too many
            [[GRDGatewayAPI new] registerAndCreateWithHostname:hostname subscriberCredential:credential validForDays:adjustedDays completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
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

- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
    [[GRDServerManager new] selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage) {
        if (!errorMessage) {
            [self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation postCredential:mid completion:completion];
            
        } else {
            if (completion) {
                completion(false, errorMessage);
            }
        }
    }];
}

- (void)configureFirstTimeUserWithRegion:(GRDRegion * _Nullable)region completion:(StandardBlock)completion {
    GRDDebugLog(@"Configure with region: %@ location: %@", region.bestHost, region.bestHostLocation);
    if (!region.bestHost && !region.bestHostLocation && region) {
        [region findBestServerWithCompletion:^(NSString * _Nonnull server, NSString * _Nonnull serverLocation, BOOL success) {
            if (success) {
                [self selectRegion:region];
                [self configureFirstTimeUserForHostname:server andHostLocation:serverLocation completion:completion];
                
            } else {
                if (completion) {
                    completion(false, [NSString stringWithFormat:@"Failed to find a host for region: %@", region.displayName]);
                }
            }
        }];
        
    } else {
        [self selectRegion:region];
        [self configureFirstTimeUserPostCredential:nil completion:completion];
    }
}

- (void)configureFirstTimeUserForHostname:(NSString *_Nonnull)host andHostLocation:(NSString *_Nonnull)hostLocation completion:(StandardBlock)completion {
    [self configureFirstTimeUserForHostname:host andHostLocation:hostLocation postCredential:nil completion:completion];
}

- (void)configureFirstTimeUserForHostname:(NSString *_Nonnull)host andHostLocation:(NSString *_Nonnull)hostLocation postCredential:(void(^__nullable)(void))mid completion:(StandardBlock)completion {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [GRDVPNHelper saveAllInOneBoxHostname:host];
    [defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
    
    [self createStandaloneCredentialsForDays:30 completion:^(NSDictionary * _Nonnull creds, NSString * _Nullable errorMessage) {
        if (errorMessage != nil) {
            GRDLog(@"%@", errorMessage);
            if (completion) {
                completion(FALSE, errorMessage);
            }
            
        } else if (creds) {
            if (mid) {
                mid();
            }
            
            NSMutableDictionary *fullCreds = [creds mutableCopy];
            fullCreds[kGRDHostnameOverride] = host;
            fullCreds[kGRDVPNHostLocation] = hostLocation;
            NSInteger adjustedDays = [GRDVPNHelper subCredentialDays];
            self.mainCredential = [[GRDCredential alloc] initWithFullDictionary:fullCreds validFor:adjustedDays isMain:true];
            [self.mainCredential saveToKeychain];
            [GRDCredentialManager addOrUpdateCredential:self.mainCredential];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
            [self configureAndConnectVPNWithCompletion:^(NSString * _Nonnull message, GRDVPNHelperStatusCode status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (status == GRDVPNHelperFail) {
                        if (message != nil) {
                            if (completion) {
                                completion(FALSE, message);
                            }
                            
                        } else {
                            if (completion) {
                                completion(FALSE, @"Configuring VPN failed due to a unknown reason. Please reset your connection and try again.");
                            }
                        }
                        
                    } else {
                        if (completion) {
                            completion(TRUE, nil);
                        }
                    }
                });
            }];
            
        } else { //no error, but creds are nil too!
            if (completion) {
                completion(false, @"Configuring VPN failed due to a credential creation issue. Please reset your connection and try again.");
            }
        }
    }];
}

- (void)validateCurrentEAPCredentialsWithCompletion:(void(^)(BOOL valid, NSString * _Nullable errorMessage))completion {
    GRDCredential *creds = [GRDCredentialManager mainCredentials];
    GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
    if (!creds && !subCred) {
        if (completion) {
            completion(FALSE, @"No valid EAP Credentials or subscriber credentials found");
        }
        
    } else {
        [[GRDGatewayAPI new] verifyEAPCredentials:creds completion:^(BOOL success, BOOL stillValid, NSString * _Nullable errorMessage, BOOL subCredInvalid) {
            if (success) {
                if (subCredInvalid) { //if this is invalid, remove it regardless of anything else.
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                }
				
                if (stillValid) {
                    if (completion) {
                        completion(TRUE, nil);
                    }
                    
                } else { //successful API return, EAP creds are currently invalid.
                    [self forceDisconnectVPNIfNecessary];
                    //create a fresh set of credentials (new user) in our current region.
                    [self configureFirstTimeUserWithRegion:self.selectedRegion completion:^(BOOL success, NSString * _Nullable errorMessage) {
                        if (completion) {
                            completion(success, errorMessage);
                        }
                    }];
                }
                
            } else { //success is false
                if (completion) {
                    completion(FALSE, errorMessage);
                }
            }
        }];
    }
}

- (void)clearLocalCache {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:kKnownGuardianHosts];
	[defaults removeObjectForKey:housekeepingTimezonesTimestamp];
	[defaults removeObjectForKey:kKnownHousekeepingTimeZonesForRegions];
	[defaults removeObjectForKey:kGuardianAllRegions];
	[defaults removeObjectForKey:kGuardianAllRegionsTimeStamp];;
	[defaults removeObjectForKey:kGRDEAPSharedHostname];
	[GRDKeychain removeGuardianKeychainItems];
	[GRDKeychain removeSubscriberCredentialWithRetries:3];
}

@end
