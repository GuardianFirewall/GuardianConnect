//
//  GRDVPNHelper.m
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import "GRDVPNHelper.h"
#import "EXTScope.h"

@import UserNotifications;

@implementation GRDVPNHelper {
    NSInteger _retryCount;
}

+ (BOOL)proMode {
    return ([self subscriptionTypeFromDefaults] == GRDPlanDetailTypeProfessional);
}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GRDVPNHelper *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GRDVPNHelper alloc] init];
    });
    return shared;
}

- (NSInteger)retryCount {
    return _retryCount;
}

- (void)setRetryCount:(NSInteger)retryCount {
    _retryCount = retryCount;
}

+ (BOOL)activeConnectionPossible {
    NSString *apiHostname = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride];
    NSString *authToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_APIAuthToken];
    NSString *eapUsername = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapUsername];
    if (apiHostname == nil || authToken == nil || eapUsername == nil) return false;
    return true;
}

+ (void)saveAllInOneBoxHostname:(NSString *)host {
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:@"GatewayHostname-Override"];
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kGRDHostnameOverride];
}

+ (void)clearVpnConfiguration {
    NSString *eapUsername = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapUsername];
    NSString *apiAuthToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_APIAuthToken];
    
    [[GRDGatewayAPI sharedAPI] invalidateEAPCredentials:eapUsername andAPIToken:apiAuthToken completion:^(BOOL success, NSString * _Nullable errorMessage) {
        if (success == NO) {
            GRDLog(@"Failed to invalidate EAP credentials: %@", errorMessage);
        }
    }];
    
    [GRDKeychain removeGuardianKeychainItems];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kGRDHostnameOverride];
    [defaults removeObjectForKey:kGRDVPNHostLocation];
    [defaults removeObjectForKey:@"GatewayHostname-Override"];
    [defaults removeObjectForKey:housekeepingTimezonesTimestamp];
    [defaults setBool:NO forKey:kAppNeedsSelfRepair];
    
    
    // make sure Settings tab UI updates to not erroneously show name of cleared server
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}

+ (BOOL)dayPassActive {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    return ([subscriptionTypeStr isEqualToString:kGuardianSubscriptionDayPassAlt] || [subscriptionTypeStr isEqualToString:kGuardianSubscriptionDayPass]);
}

+ (BOOL)isPayingUser {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return ([ud boolForKey:kGuardianSuccessfulSubscription] && [ud boolForKey:kIsPremiumUser]);
}

+ (void)setIsPayingUser:(BOOL)isPaying {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:isPaying forKey:kIsPremiumUser];
    [ud setBool:isPaying forKey:kGuardianSuccessfulSubscription];
}

+ (NSArray *)vpnOnDemandRules {
    // RULE: connect to VPN automatically if server reports that it is running OK
    NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
    vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
    vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride], kSGAPI_ServerStatus]];
    
    NSArray *onDemandArr = @[vpnServerConnectRule];
    return onDemandArr;
}


- (NEVPNProtocolIKEv2 *)prepareIKEv2ParametersForServer:(NSString *)server eapUsername:(NSString *)user eapPasswordRef:(NSData *)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
    if (@available(iOS 14.0, *)){
        //protocolConfig.includeAllNetworks = [defaults boolForKey:kGRDIncludesAllNetworks]; //TODO: comment this back in when killswitch is enabled
        if (@available(iOS 14.2, *)){
            protocolConfig.excludeLocalNetworks = [defaults boolForKey:kGRDExcludeLocalNetworks];
            protocolConfig.enforceRoutes = [defaults boolForKey:kGRDExcludeLocalNetworks];
        }
    }
    NEProxySettings *proxSettings = [self proxySettings];
    if (proxSettings){
        protocolConfig.proxySettings = proxSettings;
    }

    protocolConfig.useConfigurationAttributeInternalIPSubnet = false;
#if !TARGET_IPHONE_SIMULATOR
    if (@available(iOS 13.0, *)) {
        protocolConfig.enableFallback = [defaults boolForKey:kGRDWifiAssistEnableFallback];
    }
#endif
    // TO DO - find out if this all works fine with Always On VPN (allegedly uses two open tunnels at once, for wifi/cellular interfaces)
    // - may require settings "uniqueids" in VPN-side of config to "never" otherwise same EAP creds on both tunnels may cause an issue
    /*
     Params for VPN: AES-256, SHA-384, ECDH over the curve P-384 (DH Group 20)
     TLS for PKI: TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
     */
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
    if (currentStatus == NEVPNStatusConnected){
        [self disconnectVPN];
    } else if (currentStatus == NEVPNStatusInvalid) { //if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            currentStatus = [[[NEVPNManager sharedManager] connection] status];
            if (currentStatus == NEVPNStatusConnected){
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

- (void)createFreshUserWithSubscriberCredential:(NSString *)subscriberCredential completion:(void (^)(GRDVPNHelperStatusCode, NSString * _Nullable))completion {
    // remove previous authentication details
    [GRDKeychain removeGuardianKeychainItems];
    
    NSInteger eapCredentialsValidFor = 30;
    GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subscriberCredential];
    
    // Note from CJ 2020-11-24
    // This is incredibly primitive and will be improved soon
    if ([subCred.subscriptionType isEqualToString:kGuardianFreeTrial3Days]) {
        eapCredentialsValidFor = 3;
    }
    
    [[GRDGatewayAPI sharedAPI] registerAndCreateWithSubscriberCredential:subscriberCredential validForDays:eapCredentialsValidFor completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
        if (success == NO && errorMessage != nil) {
            completion(GRDVPNHelperFail, errorMessage);
            return;
            
        } else {
            // These values will never be nil if the API request was successful
            NSString *eapUsername = [credentials objectForKey:kKeychainStr_EapUsername];
            NSString *eapPassword = [credentials objectForKey:kKeychainStr_EapPassword];
            NSString *apiAuthToken = [credentials objectForKey:kKeychainStr_APIAuthToken];
            
            OSStatus usernameStatus = [GRDKeychain storePassword:eapUsername forAccount:kKeychainStr_EapUsername];
            if (usernameStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store eap username: %d", usernameStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store EAP Username");
                return;
            }
            
            OSStatus passwordStatus = [GRDKeychain storePassword:eapPassword forAccount:kKeychainStr_EapPassword];
            if (passwordStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store eap password: %d", passwordStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store EAP Password");
                return;
            }
            
            OSStatus apiAuthTokenStatus = [GRDKeychain storePassword:apiAuthToken forAccount:kKeychainStr_APIAuthToken];
            if (apiAuthTokenStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store api auth token: %d", apiAuthTokenStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store API Auth Token");
                return;
            }
            [[GRDGatewayAPI sharedAPI] setAPIAuthToken:apiAuthToken];
            [[GRDGatewayAPI sharedAPI] setDeviceIdentifier:eapUsername];
            
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GRDCurrentUserChanged" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GRDShouldConfigureVPN" object:nil];
            GRDLog(@"Posted GRDCurrentUserChanged and GRDShouldConfigureVPN");
            
            completion(GRDVPNHelperSuccess, nil);
        }
    }];
}

- (void)migrateUserWithCompletion:(void (^_Nullable)(BOOL success, NSString *error))completion {
    GRDServerManager *serverManager = [[GRDServerManager alloc] init];
    [serverManager selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (errorMessage != nil) {
                if (completion){
                    completion(false, errorMessage);
                }
                
            } else {
                [self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation completion:completion];
            }
        });
    }];
}

//trying to make configureAndConnectVPNWithCompletion a bit smaller and more manageable, DONT CALL DIRECTLY.

- (void)_createVPNConnectionWithCreds:(NSDictionary *)creds completion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
    NEVPNManager *vpnManager = [NEVPNManager sharedManager];
    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError) {
        if (loadError) {
            NSLog(@"[DEBUG] error loading prefs = %@", loadError);
            if (completion) completion(@"Error loading VPN configuration. If this issue persists please select Contact Technical Support in the Settings tab.", GRDVPNHelperFail);
            return;
        } else {
            NSString *vpnServer = creds[kGRDHostnameOverride];
            NSString *eapUsername = creds[kKeychainStr_EapUsername];
            NSData *eapPassword = creds[kKeychainStr_EapPassword];
            vpnManager.enabled = YES;
            vpnManager.protocolConfiguration = [self prepareIKEv2ParametersForServer:vpnServer eapUsername:eapUsername eapPasswordRef:eapPassword withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
            vpnManager.localizedDescription = @"Guardian Firewall";
            vpnManager.onDemandEnabled = YES;
            vpnManager.onDemandRules = [GRDVPNHelper vpnOnDemandRules];
            
            [vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                if (saveErr) {
                    NSLog(@"[DEBUG] error saving configuration for firewall = %@", saveErr);
                    if (completion) completion(@"Error saving the VPN configuration. Please try again.", GRDVPNHelperFail);
                    return;
                } else {
                    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError1) {
                        [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                            NSError *vpnErr;
                            [[vpnManager connection] startVPNTunnelAndReturnError:&vpnErr];
                            if (vpnErr != nil) {
                                NSLog(@"[DEBUG] vpnErr = %@", vpnErr);
                                if (completion) completion(@"Error starting VPN tunnel. Please reset your connection. If this issue persists please select Contact Technical Support in the Settings tab.", GRDVPNHelperFail);
                                return;
                            } else {
                                [[GRDGatewayAPI sharedAPI] startHealthCheckTimer];
                                if (completion) completion(nil, GRDVPNHelperSuccess);
                            }
                        }];
                    }];
                }
            }];
        }
    }];
}

- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    __block NSString *vpnServer = [defaults objectForKey:kGRDHostnameOverride];
    
    if ([defaults boolForKey:kAppNeedsSelfRepair] == YES) {
        NSLog(@"[DEBUG] MIGRATING USER!!!!!!");
        [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
            if (completion){
                if (success){
                    completion(nil, GRDVPNHelperSuccess);
                } else {
                    completion(error, GRDVPNHelperFail);
                }
            } else {
                NSLog(@"[DEBUG] NO COMPLETION BLOCK SET!!! GOING TO HAVE A BAD TIME");
            }
        }];
        return;
    }
    
    if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO) {
        NSLog(@"[DEBUG] something went wrong! bad server (%@)", vpnServer);
        if (completion) completion([NSString stringWithFormat:@"%@ is not allowed as a server hostname. If this issue persists please select Contact Technical Support in the Settings tab.", vpnServer], GRDVPNHelperFail);
        return;
    }
    
    [[GRDGatewayAPI sharedAPI] getServerStatusWithCompletion:^(GRDGatewayAPIResponse *apiResponse) {
        // GRDGatewayAPIEndpointNotFound exists for VPN node legacy reasons but will never be hit
        // It will be removed in the next iteration
        //NSLog(@"[DEBUG] APIResponse: %@", apiResponse);
        if (apiResponse.responseStatus == GRDGatewayAPIServerOK || apiResponse.responseStatus == GRDGatewayAPIEndpointNotFound) {
            NSString *apiAuthToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_APIAuthToken];
            NSString *eapUsername = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapUsername];
            NSData *eapPassword = [GRDKeychain getPasswordRefForAccount:kKeychainStr_EapPassword];
            
            if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
                
                [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                    if (completion){
                        if (success){
                            completion(nil, GRDVPNHelperSuccess);
                        } else {
                            completion(error, GRDVPNHelperFail);
                        }
                    } else {
                        NSLog(@"[DEBUG] NO COMPLETION BLOCK SET!!! GOING TO HAVE A BAD TIME");
                    }
                }];
                return;
            }
            NSDictionary *creds = @{kKeychainStr_APIAuthToken: apiAuthToken,
                                    kKeychainStr_EapUsername: eapUsername,
                                    kKeychainStr_EapPassword: eapPassword,
                                    kGRDHostnameOverride: vpnServer,
                                    
            };
            
            [self _createVPNConnectionWithCreds:creds completion:completion];
            
        } else if (apiResponse.responseStatus == GRDGatewayAPIServerInternalError || apiResponse.responseStatus == GRDGatewayAPIServerNotOK) {
            NSMutableArray *knownHostnames = [NSMutableArray arrayWithArray:[defaults objectForKey:@"kKnownGuardianHosts"]];
            for (int i = 0; i < [knownHostnames count]; i++) {
                NSDictionary *serverObject = [knownHostnames objectAtIndex:i];
                if ([[serverObject objectForKey:@"hostname"] isEqualToString:vpnServer]) {
                    [knownHostnames removeObject:serverObject];
                }
            }
            
            [defaults setObject:[NSArray arrayWithArray:knownHostnames] forKey:@"kKnownGuardianHosts"];
            [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                if (completion){
                    if (success){
                        completion(nil, GRDVPNHelperSuccess);
                    } else {
                        completion(error, GRDVPNHelperFail);
                    }
                } else {
                    NSLog(@"[DEBUG] NO COMPLETION BLOCK SET!!! GOING TO HAVE A BAD TIME");
                }
            }];
            return;
            
        } else if (apiResponse.responseStatus == GRDGatewayAPIUnknownError) {
            NSLog(@"[DEBUG][configureVPN] GRDGatewayAPIUnknownError");
            
            if (apiResponse.error.code == NSURLErrorTimedOut || apiResponse.error.code == NSURLErrorServerCertificateHasBadDate || apiResponse.error.code == GRDVPNHelperDoesNeedMigration) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] timeout error!, cert expiration error or host not found, migrating!");
                [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
                    if (completion){
                        if (success){
                            completion(nil, GRDVPNHelperSuccess);
                        } else {
                            completion(error, GRDVPNHelperFail);
                        }
                    } else {
                        NSLog(@"[DEBUG] NO COMPLETION BLOCK SET!!! GOING TO HAVE A BAD TIME");
                    }
                }];
            } else if (apiResponse.error.code == NSURLErrorNotConnectedToInternet) {
                // probably should not reach here, due to use of Reachability, but leaving this as a fallback
                NSLog(@"[DEBUG][createFreshUserWithCompletion] not connected to internet!");
                if (completion) completion(@"Your device is not connected to the internet. Please check your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorNetworkConnectionLost) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] connection lost!");
                if (completion) completion(@"Connection failed, potentially due to weak network signal. Please ty again.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorInternationalRoamingOff) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] international roaming is off!");
                if (completion) completion(@"Your device is not connected to the internet. Please turn Roaming on in your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorDataNotAllowed) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] data not allowed!");
                if (completion) completion(@"Your device is not connected to the internet. Your cellular network did not allow this connection to complete.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorCallIsActive) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] phone call active!");
                if (completion) completion(@"The connection could not be completed due to an active phone call. Please try again after completing your phone call.", GRDVPNHelperFail);
            } else {
                if (completion) completion(@"Unknown error occured. Please contact support@guardianapp.com if this issue persists.", GRDVPNHelperFail);
            }
        }
    }];
}

- (void)getValidSubscriberCredentialWithCompletion:(void(^)(NSString *credential, NSString *error))block {
    __block NSString *subCredString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential];
    
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    // Create GRDSubscriberCredential object from string stored in the keychain
    // Safe with subCredString being nil
    GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subCredString];
    NSTimeInterval safeExpirationDate = [[currentCalendar dateByAddingUnit:NSCalendarUnitDay value:-2 toDate:[NSDate date] options:0] timeIntervalSince1970];
    NSTimeInterval subCredExpirationDate = [[NSDate dateWithTimeIntervalSince1970:subCred.tokenExpirationDate] timeIntervalSince1970];
    
    if (safeExpirationDate > subCredExpirationDate || subCredString == nil) {
        // No subscriber credential yet or it is expired. We have to create a new one
        GRDLog(@"No subscriber credential present or it has passed the safe expiration point");
        GRDHousekeepingValidationMethod valmethod = ValidationMethodFreeUser;
        
        if ([GRDVPNHelper isPayingUser] == true) {
            /* i don't know this as well, and not sure if we should proceed if we dont have a PEToken when promode or pretrial token are set. but either
             way we shouldn't proceed with the PEToken validation method if we cant retreive the PEToken! -kevin */
            NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
            if (([GRDVPNHelper proMode] || [[NSUserDefaults standardUserDefaults] boolForKey:kGuardianFreeTrialPeTokenSet] == YES || [petToken containsString:@"gdp_"]) && petToken.length > 0) {
                valmethod = ValidationmethodPEToken;
            } else {
                valmethod = ValidationMethodAppStoreReceipt;
            }
        }
        
        GRDHousekeepingAPI *housekeeping = [GRDHousekeepingAPI new];
        [housekeeping createNewSubscriberCredentialWithValidationMethod:valmethod completion:^(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage) {
            if (success == NO && errorMessage != nil) {
                
                if (block) {
                    block(nil, errorMessage);
                }
                return;
                
            }  else if (success == YES) {
                [GRDKeychain removeSubscriberCredentialWithRetries:3];
                OSStatus saveStatus = [GRDKeychain storePassword:subscriberCredential forAccount:kKeychainStr_SubscriberCredential];
                if (saveStatus != errSecSuccess) {
                    if (block) {
                        block(nil, @"Couldn't save subscriber credential in local keychain. Please try again. If this issue persists please notify our technical support about your issue.");
                    }
                    return;
                }
                
                block(subscriberCredential, nil);
            }
        }];
        
    } else {
        block(subCredString, nil);
    }
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))block {
    [self createStandaloneCredentialsForDays:validForDays hostname:[[GRDGatewayAPI sharedAPI] apiHostname] completion:block];
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * creds, NSString * errorMessage))block {
    [self getValidSubscriberCredentialWithCompletion:^(NSString *credential, NSString *error) {
        if (credential != nil) {
            [[GRDGatewayAPI sharedAPI] registerAndCreateWithHostname:hostname subscriberCredential:credential validForDays:validForDays completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
                if (success == NO && errorMessage != nil) {
                    block(nil, errorMessage);
                    
                } else {
                    block(credentials, nil);
                }
            }];
            
        } else {
            block(nil,error);
        }
    }];
}

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation completion:(void(^)(BOOL success, NSString *errorMessage))block {
    [self configureFirstTimeUserForHostname:host andHostLocation:hostLocation postCredential:nil completion:block];
}

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation postCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [[GRDGatewayAPI sharedAPI] setApiHostname:host];
    [GRDVPNHelper saveAllInOneBoxHostname:host];
    [defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
    
    [self getValidSubscriberCredentialWithCompletion:^(NSString *credential, NSString *error) {
        if (error != nil) {
            GRDLog(@"Failed to obtain valid subscriber credential: %@", error);
            if (block) block(NO, error);
            return;
            
        } else {
            if (mid){
                mid();
            }
            [self createFreshUserWithSubscriberCredential:credential completion:^(GRDVPNHelperStatusCode statusCode, NSString * _Nonnull errString) {
                if (errString != nil) {
                    GRDLog(@"%@", errString);
                    if (block) {
                        block(FALSE, errString);
                    }
                    
                } else if (statusCode == GRDVPNHelperSuccess) {
                    if (block) {
                        block(TRUE, nil);
                    }
                }
            }];
        }
    }];
}

#pragma mark shared framework code

+ (GRDPlanDetailType)subscriptionTypeFromDefaults {
    NSString *subscriptionTypeStr = [[NSUserDefaults standardUserDefaults] objectForKey:kSubscriptionPlanTypeStr];
    NSArray *essSubTypes = @[kGuardianSubscriptionDayPass,
                             kGuardianSubscriptionDayPassAlt,
                             kGuardianSubscriptionAnnual,
                             kGuardianSubscriptionThreeMonths,
                             kGuardianSubscriptionMonthly,
                             kGuardianSubscriptionFreeTrial,
                             kGuardianSubscriptionTypeEssentials,
                             kGuardianFreeTrial3Days,
                             kGuardianExtendedTrial30Days,
                             kGuardianSubscriptionCustomDayPass];
    
    NSArray *proSubTypes = @[kGuardianSubscriptionTypeProfessionalYearly,
                             kGuardianSubscriptionTypeProfessionalMonthly,
                             kGuardianSubscriptionTypeVisionary,
                             kGuardianSubscriptionTypeProfessionalIAP,
                             kGuardianSubscriptionTypeProfessionalBrave];
    
    if ([essSubTypes containsObject:subscriptionTypeStr]){
        return GRDPlanDetailTypeEssentials;
    }
    if ([proSubTypes containsObject:subscriptionTypeStr]){
        return GRDPlanDetailTypeProfessional;
    }
    return GRDPlanDetailTypeFree; //maybe others??
}


@end
