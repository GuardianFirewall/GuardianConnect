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
        shared.onDemand = true;
        [shared _loadCredentialsFromKeychain]; //the API user shouldn't have to call this manually, been meaning to put this in here.
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
    if (proxSettings){
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

+ (NSInteger)subCredentialDays {
    NSInteger eapCredentialsValidFor = 30;
    GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:[GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential]];
    if (!subCred){
        GRDLog(@"[DEBUG] this is probably bad!!");
    }
    
    // Note from CJ 2020-11-24
    // This is incredibly primitive and will be improved soon
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
                if (completion){
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
    if (selectedRegion){
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
    if([defaults boolForKey:kGuardianUseFauxTimeZone]) {
        GRDRegion *region = [[GRDRegion alloc] init];
        region.regionName = [defaults valueForKey:kGuardianFauxTimeZone];
        region.displayName = [defaults valueForKey:kGuardianFauxTimeZonePretty];
        _selectedRegion = region;
    }
}

- (NSString *)currentDisplayHostname {
    GRDRegion *selected = [self selectedRegion];
    if (selected){
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
            GRDLog(@"[DEBUG] error loading prefs = %@", loadError);
            if (completion) completion(@"Error loading VPN configuration. If this issue persists please select Contact Technical Support in the Settings tab.", GRDVPNHelperFail);
            return;
        } else {
            NSString *vpnServer = self.mainCredential.hostname;
            NSString *eapUsername = self.mainCredential.username;
            GRDLog(@"server : %@ username: %@ password: %@", self.mainCredential.hostname, self.mainCredential.username, self.mainCredential.password);
            NSData *eapPassword = self.mainCredential.passwordRef;
            vpnManager.enabled = YES;
            vpnManager.protocolConfiguration = [self prepareIKEv2ParametersForServer:vpnServer eapUsername:eapUsername eapPasswordRef:eapPassword withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
            vpnManager.localizedDescription = [NSString stringWithFormat:@"Guardian Firewall: %@", [self currentDisplayHostname]];//@"Guardian Firewall";
            if ([self onDemand]) { //This defaults to YES
                vpnManager.onDemandEnabled = YES;
                vpnManager.onDemandRules = [GRDVPNHelper vpnOnDemandRules];
            } else {
                vpnManager.onDemandEnabled = NO;
            }
            [vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
                if (saveErr) {
                    GRDLog(@"[DEBUG] error saving configuration for firewall = %@", saveErr);
                    if (completion) completion(@"Error saving the VPN configuration. Please try again.", GRDVPNHelperFail);
                    return;
                } else {
                    [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError *loadError1) {
                        [vpnManager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                            NSError *vpnErr;
                            [[vpnManager connection] startVPNTunnelAndReturnError:&vpnErr];
                            if (vpnErr != nil) {
                                GRDLog(@"[DEBUG] vpnErr = %@", vpnErr);
                                if (completion) completion(@"Error starting VPN tunnel. Please reset your connection. If this issue persists please select Contact Technical Support in the Settings tab.", GRDVPNHelperFail);
                                return;
                            } else {
                                
                                GRDLog(@"[DEBUG] created successful VPN connection??");
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
        GRDLog(@"[DEBUG] kAppNeedsSelfRepair == true. MIGRATING USER!!!!!!");
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
    if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO && [vpnServer hasSuffix:@".ikev2.network"] == NO) {
        GRDLog(@"[DEBUG] something went wrong! bad server (%@). Migrating user...", vpnServer);
        [self migrateUserWithCompletion:^(BOOL success, NSString *error) {
            if (completion){
                if (success){
                    completion(nil, GRDVPNHelperSuccess);
                } else {
                    completion(error, GRDVPNHelperFail);
                }
            } else {
                GRDLog(@"[DEBUG] NO COMPLETION BLOCK SET!!! GOING TO HAVE A BAD TIME");
            }
        }];
        return;
    }
    
    [[GRDGatewayAPI new] getServerStatusWithCompletion:^(GRDGatewayAPIResponse *apiResponse) {
    
        //NSLog(@"[DEBUG] APIResponse: %@", apiResponse);
        if (apiResponse.responseStatus == GRDGatewayAPIServerOK) {
            NSString *apiAuthToken = [self.mainCredential apiAuthToken];
            NSString *eapUsername = [self.mainCredential username];
            NSData *eapPassword = [self.mainCredential passwordRef];
            
            if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
                
                GRDLog(@"[DEBUG] missing required credentials, migrating!");
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
                NSLog(@"[DEBUG][configureAndConnectVPNWithCompletion] not connected to internet!");
                if (completion) completion(@"Your device is not connected to the internet. Please check your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorNetworkConnectionLost) {
                NSLog(@"[DEBUG][configureAndConnectVPNWithCompletion] connection lost!");
                if (completion) completion(@"Connection failed, potentially due to weak network signal. Please ty again.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorInternationalRoamingOff) {
                NSLog(@"[DEBUG][configureAndConnectVPNWithCompletion] international roaming is off!");
                if (completion) completion(@"Your device is not connected to the internet. Please turn Roaming on in your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorDataNotAllowed) {
                NSLog(@"[DEBUG][configureAndConnectVPNWithCompletion] data not allowed!");
                if (completion) completion(@"Your device is not connected to the internet. Your cellular network did not allow this connection to complete.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorCallIsActive) {
                NSLog(@"[DEBUG][configureAndConnectVPNWithCompletion] phone call active!");
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
    [self createStandaloneCredentialsForDays:validForDays hostname:[[NSUserDefaults standardUserDefaults]valueForKey:kGRDHostnameOverride] completion:block];
}

- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * creds, NSString * errorMessage))block {
    [self getValidSubscriberCredentialWithCompletion:^(NSString *credential, NSString *error) {
        if (credential != nil) {
            NSInteger adjustedDays = [GRDVPNHelper subCredentialDays];
            //adjust the day count in case 30 is too many
            [[GRDGatewayAPI new] registerAndCreateWithHostname:hostname subscriberCredential:credential validForDays:adjustedDays completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
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

- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(StandardBlock)block {
    [[GRDServerManager new] selectGuardianHostWithCompletion:^(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage) {
        if (!errorMessage){
            [self configureFirstTimeUserForHostname:guardianHost andHostLocation:guardianHostLocation postCredential:mid completion:block];
        } else {
            if (block){
                block(false,errorMessage);
            }
            if (block){
                block(false,errorMessage);
            }
        }
    }];
}

- (void)configureFirstTimeUserWithRegion:(GRDRegion *)region completion:(StandardBlock)block {
    GRDLog(@"configure with region: %@ loc: %@", region.bestHost, region.bestHostLocation);
    [self configureFirstTimeUserForHostname:region.bestHost andHostLocation:region.bestHostLocation completion:block];
}

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation completion:(StandardBlock)block {
    [self configureFirstTimeUserForHostname:host andHostLocation:hostLocation postCredential:nil completion:block];
}

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation postCredential:(void(^__nullable)(void))mid completion:(StandardBlock)block {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [GRDVPNHelper saveAllInOneBoxHostname:host];
    [defaults setObject:hostLocation forKey:kGRDVPNHostLocation];
    [self createStandaloneCredentialsForDays:30 completion:^(NSDictionary * _Nonnull creds, NSString * _Nonnull errorMessage) {
        if (errorMessage != nil){
            GRDLog(@"%@", errorMessage);
            if (block) {
                block(FALSE, errorMessage);
            }
        } else if (creds){
            if (mid){
                mid();
            }
            NSMutableDictionary *fullCreds = [creds mutableCopy];
            GRDLog(@"fullCreds: %@", fullCreds);
            fullCreds[kGRDHostnameOverride] = host;
            fullCreds[kGRDVPNHostLocation] = hostLocation;
            NSInteger adjustedDays = [GRDVPNHelper subCredentialDays];
            GRDLog(@"AdjustedDays: %lu", adjustedDays);
            self.mainCredential = [[GRDCredential alloc] initWithFullDictionary:fullCreds validFor:adjustedDays isMain:true];
            [self.mainCredential saveToKeychain];
            [GRDCredentialManager addOrUpdateCredential:self.mainCredential];
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
            [self configureAndConnectVPNWithCompletion:^(NSString * _Nonnull message, GRDVPNHelperStatusCode status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (status == GRDVPNHelperFail) {
                        if (message != nil) {
                            if (block){
                                block(FALSE, message);
                            }
                        } else {
                            if (block){
                                block(FALSE, @"Configuring VPN failed due to a unknown reason. Please reset your connection and try again. If this issue persists please select Contact Technical Support in the Settings tab.");
                            }
                        }
                    } else {
                        if (block) {
                            block(TRUE, nil);
                        }
                    }
                    
                });
            }];
            
        }
    }];
}

- (void)validateCurrentEAPCredentialsWithCompletion:(void(^)(BOOL valid, NSString *errorMessage))block {
    GRDCredential *creds = [GRDCredentialManager mainCredentials];
    GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
    NSLog(@"subcred: %@", creds);
    if (!creds && !subCred){
        if (block){
            block(FALSE, @"No valid EAP Credentials or subscriber credentials found");
        }
    } else { //got em both, vaidate them.
        
        [[GRDGatewayAPI new] verifyEAPCredentialsUsername:creds.username apiToken:creds.apiAuthToken andSubscriberCredential:subCred.subscriberCredential forVPNNode:creds.hostname completion:^(BOOL success, BOOL stillValid, NSString * _Nullable errorMessage, BOOL subCredInvalid) {
            if (success) {
                if (subCredInvalid) { //if this is invalid, remove it regardless of anything else.
                    [GRDKeychain removeSubscriberCredentialWithRetries:3];
                }
                if (stillValid) {
                    if (block) {
                        block(TRUE, nil);
                    }
                    
                } else { //successful API return, EAP creds are currently invalid.
                    
                    //TODO: should this be handled differently? if they have an active VPN connection but invalid creds, should we create a fresh connection on a new host?
                    [[GRDVPNHelper sharedInstance] forceDisconnectVPNIfNecessary];
                    [GRDVPNHelper clearVpnConfiguration];
                }
                
                
            } else { //success is false
                if (block) {
                    block(FALSE, errorMessage);
                }
            }
        }];
    }
}

#pragma mark shared framework code

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

#if !TARGET_OS_OSX

#pragma mark Background Task code

- (void)startBackgroundTaskIfNecessary {
    if (self.bgTask != UIBackgroundTaskInvalid) {
        NSLog(@"[DEBUG] background task already started!");
        return;
    }
    @weakify(self);
    UIApplication *app = [UIApplication sharedApplication];
       self.bgTask = [app beginBackgroundTaskWithName:@"Guardian VPN Connection" expirationHandler:^{
           NSLog(@"[DEBUG] bg task expired!");
           [app endBackgroundTask:self_weak_.bgTask];
           self_weak_.bgTask = UIBackgroundTaskInvalid;
       }];
}

- (void)endBackgroundTask {
    UIApplication *app = [UIApplication sharedApplication];
    [app endBackgroundTask:self.bgTask];
    self.bgTask = UIBackgroundTaskInvalid;
}

#endif

@end
