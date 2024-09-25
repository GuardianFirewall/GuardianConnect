//
//  GRDVPNHelper.m
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/EXTScope.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDBlocklistItem.h>
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>
#import <GuardianConnect/GuardianConnect-Swift.h>
#import <GuardianConnect/GRDBlocklistGroup.h>


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
        [[NEVPNManager sharedManager] loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
				GRDErrorLogg(@"Failed to load IKEv2 tunnel manager preferences: %@", [error localizedDescription]);
            }
        }];
		shared->_serverFeatureEnvironment = ServerFeatureEnvironmentProduction;
        [shared refreshVariables];
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

- (void)refreshVariables {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	GRDCredential *main = [GRDCredentialManager mainCredentials];
	[self setMainCredential:main];
	
	GRDPEToken *pet = [GRDPEToken currentPEToken];
	if (pet != nil) {
		self.connectAPIHostname = pet.connectAPIEnv;
	}
	
	//
	// Note from CJ 2024-01-18
	// This ensures that the property is set to ValidationMethodInvalid if no
	// preferred validation method is set, which is crucial for the rest of the
	// system to do the right thing
	self.preferredSubscriberCredentialValidationMethod = [GRDSubscriberCredential getPreferredValidationMethod];
	
	//
	// Note from CJ 2024-01-26
	// If a preferred region is set ensure that it is properly
	// decoded and set so that the SDK routes devices to the desired servers
	if ([defaults valueForKey:kGuardianRegionOverride] != nil) {
		NSData *regionData = [defaults objectForKey:kGuardianRegionOverride];
		
		NSError *unarchiveErr;
		GRDRegion *region = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[GRDRegion class], [NSString class], [NSNumber class], [NSArray class], nil] fromData:regionData error:&unarchiveErr];
		if (unarchiveErr != nil) {
			GRDErrorLogg(@"Failed to restore selected region from user defaults: %@", [unarchiveErr localizedDescription]);
			[defaults removeObjectForKey:kGuardianRegionOverride];
			
			self.selectedRegion = nil;
			return;
		}
		
		self.selectedRegion = region;
		
	} else {
		//
		// Note from CJ 2023-05-26
		// Ensure that the automatic region is selected if
		// no region override is detected
		[self selectRegion:nil];
	}
	
	//
	// Note from CJ 2024-01-26
	// Ensure that the preferred region precision is fetched from NSUserDefaults
	self.regionPrecision = kGRDRegionPrecisionDefault;
	if ([defaults valueForKey:kGRDPreferredRegionPrecision] != nil) {
		self.regionPrecision = [defaults stringForKey:kGRDPreferredRegionPrecision];
		if ([self.regionPrecision isEqualToString:kGRDRegionPrecisionDefault] == NO && [self.regionPrecision isEqualToString:kGRDRegionPrecisionCity] == NO && [self.regionPrecision isEqualToString:kGRDRegionPrecisionCountry] == NO && [self.regionPrecision isEqualToString:kGRDRegionPrecisionCityByCountry] == NO) {
			GRDWarningLog(@"Preferred region precision '%@' does not match any of the known constants!", self.regionPrecision);
		}
	}
	
	if ([defaults valueForKey:kGRDDisconnectOnTrustedNetworks] != nil) {
		self.disconnectOnTrustedNetworks = [defaults boolForKey:kGRDDisconnectOnTrustedNetworks];
	}
	
	if ([defaults valueForKey:kGRDTrustedNetworksArray] != nil) {
		self.trustedNetworks = [defaults arrayForKey:kGRDTrustedNetworksArray];
	}
	
	if ([defaults boolForKey:kGRDSmartRountingProxyEnabled] == YES) {
		[GRDVPNHelper enableSmartProxyRouting];
	}
	
	[[NSNotificationCenter defaultCenter] addObserverForName:NSSystemTimeZoneDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
		[self checkTimezoneChanged];
	}];
}


#pragma mark - Internal setters

- (void)setConnectAPIHostname:(NSString *)connectAPIHostname {
	_connectAPIHostname = connectAPIHostname;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if (connectAPIHostname == nil) {
		[defaults removeObjectForKey:kGRDConnectAPIHostname];
		
	} else {
		[defaults setObject:connectAPIHostname forKey:kGRDConnectAPIHostname];
	}
}

- (void)setConnectPublishableKey:(NSString *)connectPublishableKey {
	_connectPublishableKey = connectPublishableKey;
	
	if (connectPublishableKey == nil) {
		[GRDKeychain removeKeychainItemForAccount:kGRDConnectPublishableKey];
		
	} else {
		[GRDKeychain storePassword:connectPublishableKey forAccount:kGRDConnectPublishableKey];
	}
}

- (void)setServerFeatureEnvironment:(GRDServerFeatureEnvironment)featureEnvironment {
	_serverFeatureEnvironment = featureEnvironment;
	[[NSUserDefaults standardUserDefaults] setInteger:featureEnvironment forKey:kGRDServerFeatureEnvironment];
}

- (void)setPreferBetaCapableServers:(BOOL)preferBetaCapableServers {
	_preferBetaCapableServers = preferBetaCapableServers;
	[[NSUserDefaults standardUserDefaults] setBool:preferBetaCapableServers forKey:kGRDBetaCapablePreferred];
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
        
		[creds revokeCredentialWithCompletion:^(NSError * _Nullable error) {
			if (error != nil) {
				GRDErrorLogg(@"Failed to invalidate main credential: %@", [error localizedDescription]);
			}
		}];
    }
    
    [GRDKeychain removeGuardianKeychainItems];
    [GRDCredentialManager clearMainCredentials];
    [[GRDVPNHelper sharedInstance] setMainCredential:nil];
    
	[GRDVPNHelper sendServerUpdateNotifications];
}

+ (void)sendServerUpdateNotifications {
	[[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}


# pragma mark - VPN Convenience

- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(void (^)(GRDVPNHelperStatusCode, NSError *))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) {
				completion(GRDVPNHelperFail, errorMessage);
				return;
			}
			
			[self configureUserFirstTimeForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] server:server postCredential:mid completion:completion];
		}
	}];
}

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol postCredentialCallback:(void (^)(void))postCredentialCallback completion:(void (^)(NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(errorMessage);
			return;
		}
		
		[self configureUserFirstTimeForTransportProtocol:protocol server:server postCredential:postCredentialCallback completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
			if (completion) completion(errorMessage);
			return;
		}];
	}];
}

- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol withRegion:(GRDRegion * _Nullable)region completion:(void(^)(GRDVPNHelperStatusCode, NSError *))completion {
	[self selectRegion:region];
	if (region != nil && region.isAutomatic == NO) {
		GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:region.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
		[serverManager findBestHostInRegion:region completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
			[self configureUserFirstTimeForTransportProtocol:protocol server:server postCredential:nil completion:completion];
		}];
		
	} else {
		[self configureUserFirstTimeForTransportProtocol:protocol postCredentialCallback:nil completion:^(NSError * _Nullable error) {
			GRDVPNHelperStatusCode status = GRDVPNHelperSuccess;
			if (error != nil) {
				status = GRDVPNHelperFail;
			}
			if (completion) completion(status, error);
		}];
	}
}

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol server:(GRDSGWServer * _Nonnull)server postCredential:(void(^__nullable)(void))mid completion:(void(^_Nullable)(GRDVPNHelperStatusCode status, NSError *_Nullable error))completion {
	[self createStandaloneCredentialsForTransportProtocol:protocol validForDays:30 server:server completion:^(NSDictionary * _Nonnull credentials, NSError * _Nonnull errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(GRDVPNHelperFail, errorMessage);
			return;
			
		} else if (credentials) {
			if (mid) mid();
			
			NSInteger adjustedDays = [self _sgwCredentialValidFor];
			self.mainCredential = [[GRDCredential alloc] initWithTransportProtocol:protocol fullDictionary:credentials server:server validFor:adjustedDays isMain:YES];
			[GRDCredentialManager addOrUpdateCredential:self.mainCredential];
			
			[self configureAndConnectVPNTunnelWithCompletion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (errorMessage == nil && status != GRDVPNHelperSuccess) {
						if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Configuring VPN failed due to a unknown reason. Please reset your connection and try again."]);
						
					} else {
						if (completion) completion(status, errorMessage);
					}
				});
			}];
			
		} else {
			if (completion) {
				completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Configuring VPN failed due to a credential creation issue. Please reset your connection and try again."]);
			}
		}
	}];
}

- (void)configureAndConnectVPNTunnelWithCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	__block GRDCredential *mainCredentials 	= [GRDCredentialManager mainCredentials];
	__block NSString *vpnServer 			= [mainCredentials hostname];
	
	if (mainCredentials == nil) {
		GRDErrorLogg(@"Main credentials missing, migrating user!");
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:completion];
		return;
	}
	
	if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO && [vpnServer hasSuffix:@".ikev2.network"] == NO) {
		GRDErrorLogg(@"Something went wrong! Bad server (%@). Migrating user...", vpnServer);
		[self migrateUserForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] withCompletion:completion];
		return;
	}
	
	[[GRDGatewayAPI new] getServerStatusWithCompletion:^(NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			GRDErrorLogg(@"VPN server status check failed with error: %@", errorMessage);
			[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:completion];
			return;
		}
		
		if ([self.mainCredential transportProtocol] == TransportIKEv2) {
			if ([self.mainCredential username] == nil || [self.mainCredential passwordRef] == nil || [self.mainCredential apiAuthToken] == nil) {
				GRDErrorLogg(@"[IKEv2] Missing one or more required credentials, migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:completion];
				return;
			}
			
			[self _startIKEv2ConnectionWithCompletion:completion];
			
		} else {
			if ([self.mainCredential serverPublicKey] == nil || [self.mainCredential IPv4Address] == nil || [self.mainCredential clientId] == nil || [self.mainCredential apiAuthToken] == nil) {
				GRDErrorLogg(@"[WireGuard] Missing required credentials or server connection details. Migrating!");
				[self migrateUserForTransportProtocol:[self.mainCredential transportProtocol] withCompletion:completion];
				return;
			}
			
			[self _startWireGuardConnectionWithCompletion:completion];
		}
	}];
}


# pragma mark - Internal VPN Functions

+ (NSArray *)_vpnOnDemandRulesForHostname:(NSString *)hostname withProbeURL:(BOOL)probeURLEnabled disconnectTrustedNetworks:(BOOL)disconntTrustedNetworks trustedNetworks:(NSArray<NSString *>  * _Nullable)trustedNetworks {
	// Create mutable array to throw on-demand rules into
	NSMutableArray *onDemandRules = [NSMutableArray new];
	
	// Create rule to disconnect the VPN automatically if the device is
	// connected to certain WiFi SSIDs.
	if (trustedNetworks != nil) {
		if ([trustedNetworks count] > 0) {
			NEOnDemandRuleDisconnect *disconnect = [NEOnDemandRuleDisconnect new];
			disconnect.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi;
			if (disconntTrustedNetworks == YES) {
				disconnect.SSIDMatch = trustedNetworks;
				[onDemandRules addObject:disconnect];
			}
		}
	}
	
	// Create rule to connect to the VPN automatically if server reports that it is running OK
	// This is done by using the probe URL. It is a GET request which has to return 200 OK as the
	// HTTP response status code. No other indicator is considered and everything but 200 OK is
	// an automatic failure preventing the device to get stuck in a loop trying to connect
	NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
	vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
	if (probeURLEnabled == YES) {
		vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/vpnsrv/api/server-status", hostname]];
	}
	
	[onDemandRules addObject:vpnServerConnectRule];
	return onDemandRules;
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
			vpnManager.enabled 					= YES;
			vpnManager.protocolConfiguration 	= [self _prepareIKEv2ParametersForServer:self.mainCredential.server eapUsername:self.mainCredential.username eapPasswordRef:self.mainCredential.passwordRef withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
			
			NSString *finalLocalizedDescription = self.tunnelLocalizedDescription;
			if (self.appendServerRegionToTunnelLocalizedDescription == YES) {
				finalLocalizedDescription = [NSString stringWithFormat:@"%@: %@", self.tunnelLocalizedDescription, self.mainCredential.hostnameDisplayValue];
			}
			vpnManager.localizedDescription = finalLocalizedDescription;
			
			if ([self onDemand]) {
				vpnManager.onDemandEnabled = YES;
				vpnManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesForHostname:self.mainCredential.hostname withProbeURL:!self.killSwitchEnabled disconnectTrustedNetworks:self.disconnectOnTrustedNetworks trustedNetworks:self.trustedNetworks];
				
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

- (NEVPNProtocolIKEv2 *)_prepareIKEv2ParametersForServer:(GRDSGWServer * _Nonnull)server eapUsername:(NSString * _Nonnull)user eapPasswordRef:(NSData * _Nonnull)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType {
	NEVPNProtocolIKEv2 *protocolConfig = [[NEVPNProtocolIKEv2 alloc] init];
	protocolConfig.serverAddress = server.hostname;
	protocolConfig.serverCertificateCommonName = server.hostname;
	protocolConfig.remoteIdentifier = server.hostname;
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
    
	
	protocolConfig.proxySettings = [GRDVPNHelper proxySettingsForSGWServer:server];
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
		protocol.serverAddress 				= self.mainCredential.hostname;
		protocol.providerBundleIdentifier 	= self.tunnelProviderBundleIdentifier;
		protocol.passwordReference 			= [GRDKeychain getPasswordRefForAccount:kKeychainStr_WireGuardConfig];
		protocol.username 					= [self.mainCredential clientId];
		protocol.proxySettings = [GRDVPNHelper proxySettingsForSGWServer:self.mainCredential.server];
		
		if (@available(iOS 14.2, *)) {
			protocol.includeAllNetworks = self.killSwitchEnabled;
			protocol.excludeLocalNetworks = YES;
		}
		
		tunnelManager.protocolConfiguration = protocol;
		tunnelManager.enabled = YES;
		tunnelManager.onDemandEnabled = YES;
		tunnelManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesForHostname:self.mainCredential.hostname withProbeURL:!self.killSwitchEnabled disconnectTrustedNetworks:self.disconnectOnTrustedNetworks trustedNetworks:self.trustedNetworks];
		
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

- (void)disconnectVPNWithCompletion:(void (^)(NSError * _Nullable))completion {
	NEVPNManager *vpnManager = [NEVPNManager sharedManager];
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	__block NSError *tunnelError = nil;
	dispatch_group_t group = dispatch_group_create();
	
	dispatch_group_enter(group);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if (vpnManager.enabled == YES) {
			GRDWarningLogg(@"Disconnecting IKEv2 VPN");
			// Note from CJ 2022-02-23:
			// You may think that we do not want to disable the VPN profile
			// but as it turns out we are triggering some other bananas bug with the
			// WireGuard integration which means that if it's not set to enable == NO
			// the IKEv2 connection after switching protocols from WireGuard -> IKEv2
			// will get stuck in a connection loop
			[vpnManager setEnabled:NO];
			[vpnManager setOnDemandEnabled:NO];
			[vpnManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
				if (saveErr != nil) {
					GRDErrorLogg(@"Failed to disconnect IKEv2 tunnel: %@", saveErr);
					tunnelError = saveErr;
				}
				[[vpnManager connection] stopVPNTunnel];
				dispatch_group_leave(group);
			}];
			
		} else {
			dispatch_group_leave(group);
		}
	});
	
	dispatch_group_enter(group);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if (tunnelManager.enabled == YES) {
			GRDWarningLogg(@"Disconnecting WireGuard VPN");
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
					tunnelError = error;
				}
				dispatch_group_leave(group);
			}];
			// Note from CJ 2023-02-20
			// It may seems as though we'd want the line below in the completion handler from removeFromPreferencesWithCompletionHandler
			// but if I recall correctly, this was done this was specifically to thread the needle on the race condition within
			// the NetworkExtension.framework to actually be able to disconnect the WireGuard connection successfully
			// This might seem very dangerous but should remain as is for now
			[(NETunnelProviderSession *)tunnelManager.connection stopTunnel];
			
#else
			[tunnelManager saveToPreferencesWithCompletionHandler:^(NSError *saveErr) {
				if (saveErr != nil) {
					GRDErrorLogg(@"Failed to disconnect WireGuard tunnel: %@", saveErr);
					tunnelError = saveErr;
				}
				[(NETunnelProviderSession *)tunnelManager.connection stopVPNTunnel];
				dispatch_group_leave(group);
			}];
#endif
			
		} else {
			dispatch_group_leave(group);
		}
	});
	

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (completion) completion(tunnelError);
	});
}

- (void)forceDisconnectVPNIfNecessary {
	__block NEVPNStatus ikev2Status = [[[NEVPNManager sharedManager] connection] status];
	if (ikev2Status == NEVPNStatusConnected || ikev2Status == NEVPNStatusConnecting) {
		[self disconnectVPNWithCompletion:nil];

	} else if (ikev2Status == NEVPNStatusInvalid || ikev2Status == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			ikev2Status = [[[NEVPNManager sharedManager] connection] status];
			if (ikev2Status == NEVPNStatusConnected) {
				[self disconnectVPNWithCompletion:nil];
			}
		});
	}
	
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	__block NEVPNStatus wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
	if (wireguardStatus == NEVPNStatusConnected || wireguardStatus == NEVPNStatusConnecting) {
		[self disconnectVPNWithCompletion:nil];

	} else if (wireguardStatus == NEVPNStatusInvalid || wireguardStatus == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
			if (wireguardStatus == NEVPNStatusConnected) {
				[self disconnectVPNWithCompletion:nil];
			}
		});
	}
	
	// Blocking the thread for one second to allow everything else
	// to catch up as the NEVPN... API have the potential to be slow
	// This way we can prevent any network race conditions in other
	// API calls
	sleep(1);
}

- (void)resetAllGuardianConnectValues {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:kGuardianRegionOverride];
	[defaults removeObjectForKey:kGRDPreferredRegionPrecision];
	[defaults removeObjectForKey:kGRDTrustedNetworksArray];
	[defaults removeObjectForKey:kGRDDisconnectOnTrustedNetworks];
	[defaults removeObjectForKey:kGuardianTransportProtocol];
	[defaults removeObjectForKey:kGRDDeviceFilterConfigBlocklist];
	
	[GRDKeychain removeAllKeychainItems];
	[GRDKeychain removeSubscriberCredentialWithRetries:3];
	[GRDKeychain removeKeychainItemForAccount:kKeychainStr_PEToken];
	[GRDKeychain removeKeychainItemForAccount:kGuardianCredentialsList];
	[GRDKeychain removeKeychainItemForAccount:kGuardianConnectSubscriberSecret];
}


# pragma mark - Credential Creation Helper

- (void)getValidSubscriberCredentialWithCompletion:(void (^)(GRDSubscriberCredential * _Nullable subscriberCredential, NSError * _Nullable errorMessage))completion {
	// Use convenience method to get access to our current subscriber cred (if it exists)
	GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
	BOOL expired = [subCred tokenExpired];
	// check current Subscriber Credential if it exists
	if (expired == YES || subCred == nil) {
		// No subscriber credential yet or it is expired. We have to create a new one
		GRDWarningLog(@"No subscriber credential present or it has passed the safe expiration point");
		
		//
		// Prepare local variables to generate a new Subscriber Crednetial
		GRDHousekeepingValidationMethod valmethod = ValidationMethodInvalid;
		NSMutableDictionary *customKeys = [NSMutableDictionary new];
		
		// Check whether a preferred validation method is pre-defined and if yes
		// exclusively attempt to generate Subscriber Credentials with this validation method
		if (self.preferredSubscriberCredentialValidationMethod != ValidationMethodInvalid) {
			valmethod = self.preferredSubscriberCredentialValidationMethod;
			
		} else {
			//
			// Auto mode attempting to detect what kind of subscription
			// the current user most likely has...
			
			// Default to AppStore Receipt
			valmethod = ValidationMethodAppStoreReceipt;
			
			// Check to see if we have a PEToken
			NSString *petToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
			if (petToken.length > 0) {
				valmethod = ValidationMethodPEToken;
				
			} else if (self.customSubscriberCredentialAuthKeys != nil) {
				valmethod = ValidationMethodCustom;
			}
		}
		
		if (valmethod == ValidationMethodCustom) {
			customKeys = self.customSubscriberCredentialAuthKeys;
		}
		
		[[GRDHousekeepingAPI new] createSubscriberCredentialForBundleId:[[NSBundle mainBundle] bundleIdentifier] withValidationMethod:valmethod customKeys:customKeys completion:^(NSString * _Nullable subscriberCredential, BOOL success, NSError * _Nullable errorMessage) {
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
						completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Couldn't save subscriber credential in local keychain. Please try again."]);
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

//
// Note from CJ 2024-04-20
// This function should probably take a GRDCredential or a GRDSGWServer object 
// instead of just a hostname so that I have enough details down the road
// to store relevant metadata alongside the credential
- (void)createStandaloneCredentialsForTransportProtocol:(TransportProtocol)protocol validForDays:(NSInteger)days server:(GRDSGWServer *)server completion:(void (^)(NSDictionary * credentials, NSError * error))completion {
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential *subscriberCredential, NSError *error) {
		if (subscriberCredential != nil) {
			NSInteger adjustedDays = [self _sgwCredentialValidFor];
			//adjust the day count in case 30 is too many

			if (protocol == TransportIKEv2) {
				[[GRDGatewayAPI new] registerDeviceForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:server.hostname subscriberCredential:subscriberCredential.jwt validForDays:adjustedDays transportOptions:@{} completion:^(NSDictionary * _Nullable credentialDetails, BOOL success, NSString * _Nullable errorMessage) {
					if (success == NO && errorMessage != nil) {
						completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:errorMessage]);

					} else {
						completion(credentialDetails, nil);
					}
				}];
				
			} else {
				GRDCurve25519 *keys = [[GRDCurve25519 alloc] init];
				[keys generateKeyPair];
				
				[[GRDGatewayAPI new] registerDeviceForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:server.hostname subscriberCredential:subscriberCredential.jwt validForDays:adjustedDays transportOptions:@{@"public-key":keys.publicKey} completion:^(NSDictionary * _Nullable credentialDetails, BOOL success, NSString * _Nullable errorMessage) {
					if (success == NO && errorMessage != nil) {
						if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:errorMessage]);
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
			if (completion) completion(nil, error);
		}
	}];
}

- (NSInteger)_sgwCredentialValidFor {
	NSInteger eapCredentialsValidFor = 30;
	GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
	if (!subCred) {
		GRDWarningLogg(@"No Subscriber Credential present");
	}
	
	// Note from CJ 2020-11-24
	// This is incredibly primitive and will be improved soon
	//
	// Note from CJ 2021-11-01
	// This was a lie
	//
	// Note from CJ 2024-07-12
	// Still not fixed, still working
	if ([subCred.subscriptionType isEqualToString:kGuardianFreeTrial3Days]) {
		eapCredentialsValidFor = 3;
	}
	return eapCredentialsValidFor;
}

# pragma mark - Credential Validation Helper

- (void)verifyMainCredentialsWithCompletion:(void(^)(BOOL valid, NSError * _Nullable error))completion {
	GRDCredential *mainCreds = [GRDCredentialManager mainCredentials];
	if (mainCreds == nil) {
		if (completion) completion(NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"No main VPN credentials found"]);
		return;
	}
	
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential * _Nullable subscriberCredential, NSError * _Nullable error) {
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
						GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
						[serverManager findBestHostInRegion:[self selectedRegion] completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
							[self configureUserFirstTimeForTransportProtocol:mainCreds.transportProtocol server:server postCredential:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
								if (completion) completion(YES, errorMessage);
							}];
						}];
					
					} else {
						if (completion) completion(NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:errorMessage]);
						return;
					}
				}
				
			} else {
				if ([self isConnected] == NO) {
					[self forceDisconnectVPNIfNecessary];
					//create a fresh set of credentials (new user) in our current region.
					GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
					[serverManager findBestHostInRegion:[self selectedRegion] completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
						[self configureUserFirstTimeForTransportProtocol:mainCreds.transportProtocol server:server postCredential:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
							if (errorMessage != nil) {
								if (completion) completion(NO, errorMessage);
							}
							
							if (completion) completion(YES, nil);
						}];
					}];
				
				} else {
					if (completion) completion(NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:errorMessage]);
					return;
				}
			}
		}];
	}];
}

# pragma mark - Migration Helper

- (void)migrateUserForTransportProtocol:(TransportProtocol)protocol withCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(GRDVPNHelperFail, errorMessage);
			return;
		}
		
		[self configureUserFirstTimeForTransportProtocol:protocol server:server postCredential:nil completion:completion];
	}];
}

- (NSError * _Nullable)selectRegion:(GRDRegion * _Nullable)selectedRegion {
	_selectedRegion = selectedRegion;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (selectedRegion != nil && selectedRegion.isAutomatic == NO) {
		NSError *archiveErr;
		NSData *regionData = [NSKeyedArchiver archivedDataWithRootObject:selectedRegion requiringSecureCoding:YES error:&archiveErr];
		if (archiveErr != nil) {
			return archiveErr;
		}
		[defaults setObject:regionData forKey:kGuardianRegionOverride];
		
	} else {
		//resetting the value to nil, (Automatic)
		GRDLogg(@"Automatic region selection selected. Resetting all faux values");
		self.selectedRegion = nil;
		[defaults removeObjectForKey:kGuardianRegionOverride];
	}
	
	return nil;
}

- (void)setPreferredRegionPrecision:(NSString *)precision {
	self.regionPrecision = precision;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([precision isEqualToString:kGRDRegionPrecisionDefault] == YES) {
		//
		// Note from CJ 2024-01-26
		// By removing the key we attempt to guarantee that the SDK will
		// always return back to the desired default value defined in the
		// initalization function for GRDVPNHelper
		[defaults removeObjectForKey:kGRDPreferredRegionPrecision];
		
	} else {
		[defaults setObject:precision forKey:kGRDPreferredRegionPrecision];
	}
}

- (void)defineTrustedNetworksEnabled:(BOOL)enabled onTrustedNetworks:(NSArray<NSString *> *)trustedNetworks {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([trustedNetworks count] < 1 || trustedNetworks == nil) {
		self.disconnectOnTrustedNetworks = NO;
		self.trustedNetworks = nil;
		[defaults removeObjectForKey:kGRDDisconnectOnTrustedNetworks];
		[defaults removeObjectForKey:kGRDTrustedNetworksArray];
	}
	
	self.disconnectOnTrustedNetworks = enabled;
	self.trustedNetworks = trustedNetworks;
	[defaults setBool:enabled forKey:kGRDDisconnectOnTrustedNetworks];
	[defaults setObject:trustedNetworks forKey:kGRDTrustedNetworksArray];
}

- (void)allRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> * _Nullable, NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:ServerFeatureEnvironmentProduction betaCapableServers:NO];
	[serverManager allRegionsWithCompletion:^(NSArray<GRDRegion *> * _Nullable regions, NSError * _Nullable errorMessage) {
		if (completion) completion(regions, errorMessage);
	}];
}

- (void)checkTimezoneChanged {
	// Don't bother doing anything if there is no callback handler set
	if (self.timezoneChangedBlock == nil) return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults valueForKey:kGRDLastKnownAutomaticRegion] == nil) {
		GRDDebugLog(@"No previous known automatic region found.");
		return;
	}
	
	NSData *regionData = [defaults objectForKey:kGRDLastKnownAutomaticRegion];
	NSError *decodeError;
	GRDRegion * __block lastKnownAutomaticRegion = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[GRDRegion class], [NSString class], [NSNumber class], [NSArray class], nil] fromData:regionData error:&decodeError];
	if (decodeError != nil) {
		GRDErrorLogg(@"Failed to decode archived automatic GRDRegion out of NSUserDefaults: %@", [decodeError localizedDescription]);
		return;
	}
	
	if (lastKnownAutomaticRegion == nil || [lastKnownAutomaticRegion.timeZoneName isEqualToString:@""]) {
		GRDDebugLog(@"No previous known automatic region found or time zone name key missing.");
		return;
	}
	
	NSTimeZone *local = [NSTimeZone localTimeZone];
	if ([lastKnownAutomaticRegion.timeZoneName isEqualToString:[local name]] == NO) {
		GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
		[serverManager selectAutomaticModeRegion:^(GRDRegion * _Nullable automaticRegion, NSError * _Nullable error) {
			if (error != nil) {
				GRDErrorLogg(@"Failed to match automatic mode to local time zone: %@", [error localizedDescription]);
				return;
			}
			
			if (self.timezoneChangedBlock) self.timezoneChangedBlock(YES, lastKnownAutomaticRegion, automaticRegion);
		}];
	}
}

- (void)clearLocalCache {
	[GRDKeychain removeGuardianKeychainItems];
	[GRDKeychain removeSubscriberCredentialWithRetries:3];
}


# pragma mark - Smart Routing Proxy

+ (void)requestAllSmartProxyHostsWithCompletion:(void (^)(NSArray<GRDSmartProxyHost *> * _Nullable, NSError * _Nullable))completion {
	[[GRDHousekeepingAPI new] requestSmartProxyRoutingHostsWithCompletion:^(NSArray * _Nullable smartProxyHosts, NSError * _Nullable error) {
		if (error != nil) {
			GRDErrorLogg(@"Failed to request smart proxy hosts: %@", error);
			if (completion) completion(nil, error);
			return;
		}
		
		NSMutableArray <GRDSmartProxyHost *> *parsedHosts = [NSMutableArray new];
		for (NSDictionary *rawHost in smartProxyHosts) {
			GRDSmartProxyHost *parsedHost = [[GRDSmartProxyHost alloc] initFromDictionary:rawHost];
			[parsedHosts addObject:parsedHost];
		}
		
		if (completion) completion(parsedHosts, nil);
	}];
}

+ (BOOL)smartProxyRoutingEnabled {
	return [[NSUserDefaults standardUserDefaults] boolForKey:kGRDSmartRountingProxyEnabled];
}

+ (void)toggleSmartProxyRouting:(BOOL)enabled {
	if (enabled == YES) {
		[GRDVPNHelper enableSmartProxyRouting];
		
	} else {
		[GRDVPNHelper disableSmartProxyRouting];
	}
}

+ (void)enableSmartProxyRouting {
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:kGRDSmartRountingProxyEnabled];
	[GRDVPNHelper requestAllSmartProxyHostsWithCompletion:^(NSArray<GRDSmartProxyHost *> * _Nullable hosts, NSError * _Nullable error) {
		if (error != nil) {
			GRDErrorLogg(@"Failed to request smart routing proxy hosts: %@", [error localizedDescription]);
			
		} else {
			[[GRDVPNHelper sharedInstance] setSmartProxyRoutingHosts:hosts];
			
			if ([[GRDVPNHelper sharedInstance] isConnected] == YES || [[GRDVPNHelper sharedInstance] isConnecting] == YES) {
				[[GRDVPNHelper sharedInstance] configureAndConnectVPNTunnelWithCompletion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
					if (status != GRDVPNHelperSuccess) {
						GRDErrorLogg(@"Failed to re-establish VPN connection after enabling Smart Proxy Routing:", [errorMessage localizedDescription]);
					}
				}];
			}
		}
	}];
}

+ (void)disableSmartProxyRouting {
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGRDSmartRountingProxyEnabled];
	[[GRDVPNHelper sharedInstance] setSmartProxyRoutingHosts:nil];
	
	if ([[GRDVPNHelper sharedInstance] isConnected] == YES || [[GRDVPNHelper sharedInstance] isConnecting] == YES) {
		[[GRDVPNHelper sharedInstance] configureAndConnectVPNTunnelWithCompletion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
			if (status != GRDVPNHelperSuccess) {
				GRDErrorLogg(@"Failed to re-establish VPN connection after enabling Smart Proxy Routing:", [errorMessage localizedDescription]);
			}
		}];
	}
}

+ (NEProxySettings *)proxySettingsForSGWServer:(GRDSGWServer *)server {
	NEProxySettings *proxySettings = [NEProxySettings new];
	NSString *blocklistJS = [GRDVPNHelper proxyPACString];
	if (blocklistJS != nil && server.smartProxyRoutingEnabled == YES) {
		GRDDebugLog(@"Applied PAC: %@", blocklistJS);
		proxySettings.autoProxyConfigurationEnabled = YES;
		proxySettings.proxyAutoConfigurationJavaScript = blocklistJS;
		
	} else {
		proxySettings.autoProxyConfigurationEnabled = NO;
		proxySettings.proxyAutoConfigurationJavaScript = nil;
	}
	
	return proxySettings;
}

+ (NSString *)proxyPACString {
	NSArray <GRDBlocklistItem *> *blocklist = [GRDVPNHelper enabledBlocklistItems];

	// Start the if statement
	NSMutableString *matchString = [[NSMutableString alloc] initWithString:@"if ("];
	NSMutableString *proxyMatchString = [[NSMutableString alloc] initWithString:@"if ("];
	NSString *badRouteProxy = @"\"PROXY 192.0.2.222:3421\"";
	NSString *dcProxy = @"\"PROXY 10.183.10.11:3128; DIRECT\"";

	NSMutableArray *smartProxyItems = [NSMutableArray new];
	NSMutableArray *proxyItems = [NSMutableArray new];
	for (GRDBlocklistItem *item in blocklist) {
		if (item.smartProxyType == YES) {
			[smartProxyItems addObject:item];

		} else {
			[proxyItems addObject:item];
		}
	}

	NSArray *smm = [[GRDVPNHelper sharedInstance] smartProxyRoutingHosts];
	for (GRDSmartProxyHost *smartProxyHost in smm) {
		GRDBlocklistItem *conv = [GRDBlocklistItem new];
		conv.value = smartProxyHost.host;
		conv.type = GRDBlocklistTypeDNS;
		conv.enabled = YES;
		conv.smartProxyType = YES;
		[smartProxyItems addObject:conv];
	}

	for (int idx = 0; idx < [proxyItems count]; idx++) {
		NSString *formattedString = nil;
		GRDBlocklistItem *item = proxyItems[idx];

		if (item.type == GRDBlocklistTypeDNS) {
			// Keep addding || (logical OR) until we know we are the last item
			formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\") || ", item.value];

			// Last item, wrap it up
			if (idx  == proxyItems.count - 1) {
				formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\")) return %@; ", item.value, badRouteProxy];
			}

		} else if (item.type == GRDBlocklistTypeIPv4 || item.type == GRDBlocklistTypeIPv6) {
			// Keep addding || (logical OR) until we know we are the last item
			formattedString = [NSString stringWithFormat:@"(host == \"%@\") || ", item.value];

			// Last item, wrap it up
			if (idx  == proxyItems.count - 1) {
				formattedString = [NSString stringWithFormat:@"(host == \"%@\")) return %@; ", item.value, badRouteProxy];
			}

		} else {
			GRDErrorLogg(@"Unknown blocklist item type: %d", GRDBlocklistTypeFromInteger(item.type));
			continue;
		}

		[matchString appendString:formattedString];
	}

	for (int idx = 0; idx < [smartProxyItems count]; idx++) {
		NSString *formattedString = nil;
		GRDBlocklistItem *item = smartProxyItems[idx];
		if (item.type == GRDBlocklistTypeDNS) {
			// Keep addding || (logical OR) until we know we are the last item
			formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\") || ", item.value];

			// Last item, wrap it up
			if (idx  == smartProxyItems.count - 1) {
				formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\")) return %@; ", item.value, dcProxy];
			}

		} else if (item.type == GRDBlocklistTypeIPv4 || item.type == GRDBlocklistTypeIPv6) {
			// Keep addding || (logical OR) until we know we are the last item
			formattedString = [NSString stringWithFormat:@"(host == \"%@\") || ", item.value];

			// Last item, wrap it up
			if (idx  == smartProxyItems.count - 1) {
				formattedString = [NSString stringWithFormat:@"(host == \"%@\")) return %@;", item.value, dcProxy];
			}

		} else {
			GRDErrorLogg(@"Unknown blocklist item type: %d", GRDBlocklistTypeFromInteger(item.type));
			continue;
		}

		[proxyMatchString appendString:formattedString];
	}

	NSString *pacString = @"function FindProxyForURL(url, host) { ";
	if ([blocklist count] > 0 || [smartProxyItems count] > 0) {
		if ([proxyItems count] > 0) { //only add these changes if the blocklist has any enabled items.
			pacString = [pacString stringByAppendingString:matchString];
		}

		if ([smartProxyItems count] > 0) {
			pacString = [pacString stringByAppendingString:proxyMatchString];
		}

		return [pacString stringByAppendingString:@"return \"DIRECT\";}"];
	}

	return nil;
}

+ (NSArray<GRDBlocklistItem *> *)enabledBlocklistItems {
	BOOL blocklistsEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kGRDBlocklistsEnabled];
	if (blocklistsEnabled == NO) {
		return nil;
	}
	
	__block NSMutableArray *enabledItems = [NSMutableArray new];
	NSArray <GRDBlocklistGroup*> *enabledGroups = [[GRDVPNHelper blocklistGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"allDisabled == false"]];
	[enabledGroups enumerateObjectsUsingBlock:^(GRDBlocklistGroup * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if ([obj allEnabled]) {
			[enabledItems addObjectsFromArray:obj.items];
			
		} else { //check individually
			NSArray *enabled = [[obj items] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == true"]];
			[enabledItems addObjectsFromArray:enabled];
		}
	}];
	
	return enabledItems;
}

+ (NSArray<GRDBlocklistGroup *> *)blocklistGroups {
	NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups];
	NSMutableArray<GRDBlocklistGroup*> *blocklistGroups = [NSMutableArray array];
	for (NSData *item in items) {
		GRDBlocklistGroup *blocklistGroup = [NSKeyedUnarchiver unarchiveObjectWithData:item];
		[blocklistGroups addObject:blocklistGroup];
	}
	
	return blocklistGroups;
}

+ (void)updateOrAddGroup:(GRDBlocklistGroup *)group {
	NSMutableArray *modifiedArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups] mutableCopy];
	GRDBlocklistGroup *oldGroup = [GRDVPNHelper groupWithIdentifier:group.identifier];
	NSInteger objectIndex = [[GRDVPNHelper blocklistGroups] indexOfObject:oldGroup];
	if (objectIndex == NSNotFound) {
		[GRDVPNHelper addBlocklistGroup:group];
		return;
		
	} else {
		NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject:group];
		[modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
	}
	[[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDBlocklistGroups];
}

+ (GRDBlocklistGroup *)groupWithIdentifier:(NSString *)groupIdentifier {
	NSArray <GRDBlocklistGroup*> *groups = [GRDVPNHelper blocklistGroups];
	return [[groups filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", groupIdentifier]] lastObject];
}

+ (void)addBlocklistGroup:(GRDBlocklistGroup *)blocklistGroupItem {
	if (!blocklistGroupItem) { return; }
	NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups];
	NSMutableArray<NSData *> *blocklistGroups = [NSMutableArray arrayWithArray:storedItems];
	if (!blocklistGroups.count) {
		blocklistGroups = [NSMutableArray array];
	}
	[blocklistGroups insertObject:[NSKeyedArchiver archivedDataWithRootObject:blocklistGroupItem] atIndex:0];
	[[NSUserDefaults standardUserDefaults] setValue:blocklistGroups forKey:kGRDBlocklistGroups];
}

+ (void)mergeOrAddGroup:(GRDBlocklistGroup *)group {
    NSMutableArray *modifiedArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups] mutableCopy];
    GRDBlocklistGroup *oldGroup = [GRDVPNHelper groupWithIdentifier:group.identifier];
    NSInteger objectIndex = [[GRDVPNHelper blocklistGroups] indexOfObject:oldGroup];
    if (objectIndex == NSNotFound) {
        [GRDVPNHelper addBlocklistGroup:group];
        return;

    } else {
        GRDBlocklistGroup *mergedGroup = [oldGroup updateIfNeeded:group];
        NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject:mergedGroup];
        [modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
    }
    [[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDBlocklistGroups];
}

+ (void)removeBlocklistGroup:(GRDBlocklistGroup *)blocklistGroupItem {
    if (!blocklistGroupItem) { return; }
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups];
    NSMutableArray<NSData *> *blocklistGroups = [NSMutableArray arrayWithArray:storedItems];
    if (blocklistGroups.count) {
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:blocklistGroupItem];
        [blocklistGroups removeObject:itemData];
        [[NSUserDefaults standardUserDefaults] setValue:blocklistGroups forKey:kGRDBlocklistGroups];
    }
}

+ (void)clearBlocklistData {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDBlocklistGroups];
}

@end
