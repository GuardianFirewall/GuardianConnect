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
	
	if ([defaults valueForKey:kGRDDisconnectOnEthernet] != nil) {
		self.disconnectOnEthernet = [defaults boolForKey:kGRDDisconnectOnEthernet];
	}
	
	if ([defaults valueForKey:kGRDTrustedNetworksArray] != nil) {
		self.trustedNetworks = [defaults arrayForKey:kGRDTrustedNetworksArray];
	}
	
	if ([defaults valueForKey:kGRDKillSwitchEnabled] != nil) {
		self.vpnKillSwitchEnabled = [defaults boolForKey:kGRDKillSwitchEnabled];
	}
	
	if ([defaults boolForKey:kGRDSmartRountingProxyEnabled] == YES) {
		[GRDVPNHelper enableSmartProxyRouting];
	}
	
	[[NSNotificationCenter defaultCenter] addObserverForName:NSSystemTimeZoneDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
		[self checkTimeZoneChanged];
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
    GRDCredential *mainCredentials = [GRDCredentialManager mainCredentials];
	if (mainCredentials.transportProtocol == TransportIKEv2) {
		if (mainCredentials.hostname == nil || mainCredentials.apiAuthToken == nil || mainCredentials.clientId == nil) {
			return NO;
		}
		
		return YES;
		
	} else if (mainCredentials.transportProtocol == TransportWireGuard) {
		if (mainCredentials.hostname == nil || mainCredentials.apiAuthToken == nil || mainCredentials.clientId == nil || mainCredentials.devicePrivateKey == nil || mainCredentials.serverPublicKey == nil) {
			return NO;
		}
		
		return YES;
    }
	
	return NO;
}

+ (void)clearVPNConfiguration {
    GRDCredential *creds = [GRDCredentialManager mainCredentials];
    if (creds != nil) {
		[creds revokeCredentialWithCompletion:^(NSError * _Nullable error) {
			if (error != nil) {
				GRDErrorLogg(@"Failed to invalidate main credential: %@", [error localizedDescription]);
			}
		}];
    }
    
    [GRDKeychain removeGuardianKeychainItems];
}


# pragma mark - VPN Tunnels & Credentials

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol postCredentialCallback:(void (^)(void))postCredentialCallback completion:(void (^)(GRDVPNHelperStatusCode status, NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:_preferBetaCapableServers];
	[serverManager selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(GRDVPNHelperFail, errorMessage);
			return;
		}
		
		[self configureUserFirstTimeForTransportProtocol:protocol server:server connectionStatus:nil completion:completion];
//		[self configureUserFirstTimeForTransportProtocol:protocol server:server postCredential:postCredentialCallback completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage) {
//			if (completion) completion(errorMessage);
//			return;
//		}];
	}];
}

- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol withRegion:(GRDRegion * _Nullable)region completion:(void(^)(GRDVPNHelperStatusCode, NSError *))completion {
	[self selectRegion:region];
	if (region != nil && region.isAutomatic == NO) {
		GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:region.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
		[serverManager findBestHostInRegion:region completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
			[self configureUserFirstTimeForTransportProtocol:protocol server:server connectionStatus:nil completion:completion];
		}];
		
	} else {
		[self configureUserFirstTimeForTransportProtocol:protocol postCredentialCallback:nil completion:completion];
	}
}

- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol server:(GRDSGWServer *)server connectionStatus:(void (^)(GRDVPNHelperConnectionStatus))status completion:(void (^)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	if (status) status(GRDVPNHelperConnectionObtainingNewCredential);
	[self createStandaloneCredentialsForTransportProtocol:protocol validForDays:30 server:server completion:^(NSDictionary * _Nonnull credentials, NSError * _Nonnull errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(GRDVPNHelperFail, errorMessage);
			return;
			
		} else if (credentials) {
			if (status) status(GRDVPNhelperConnectionObtainedNewCredential);
			
			NSInteger adjustedDays = [self _sgwCredentialValidFor];
			GRDCredential *mainCredentials = [[GRDCredential alloc] initWithTransportProtocol:protocol fullDictionary:credentials server:server validFor:adjustedDays isMain:YES];
			[GRDCredentialManager addOrUpdateCredential:mainCredentials];
			[self connectVPNTunnelWithConnectionStatus:status completion:completion];
			
		} else {
			if (completion) {
				completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Configuring VPN failed due to a credential creation issue."]);
			}
		}
	}];
}

- (void)connectVPNTunnelWithConnectionStatus:(void (^)(GRDVPNHelperConnectionStatus connectionStatus))status completion:(void (^)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
	__block GRDCredential *mainCredentials 	= [GRDCredentialManager mainCredentials];
	
	if (![GRDVPNHelper activeConnectionPossible]) {
		if (status) status(GRDVPNHelperConnectionObtainingNewCredential);
		GRDServerManager *serverManager = [[GRDServerManager alloc] initWithServerFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
		[serverManager selectGuardianHostWithCompletion:^(GRDSGWServer * _Nullable server, NSError * _Nullable errorMessage) {
			if (errorMessage != nil) {
				if (completion) completion(GRDVPNHelperFail, errorMessage);
				return;
			}
			if (status) status(GRDVPNHelperConnectionSelectedSGWServer);
			
			TransportProtocol preferredProtocol = [GRDTransportProtocol getUserPreferredTransportProtocol];
			[self createStandaloneCredentialsForTransportProtocol:[GRDTransportProtocol getUserPreferredTransportProtocol] validForDays:30 server:server completion:^(NSDictionary * _Nullable credentials, NSError * _Nullable error) {
				if (error != nil) {
					if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to register new device credential with host: '%@': %@", [server hostname], error]]);
					return;
				}
				
				NSInteger adjustedDays = [self _sgwCredentialValidFor];
				GRDCredential *newMainCredentials = [[GRDCredential alloc] initWithTransportProtocol:preferredProtocol fullDictionary:credentials server:server validFor:adjustedDays isMain:YES];
				[GRDCredentialManager addOrUpdateCredential:newMainCredentials];
				mainCredentials = newMainCredentials;
				if (status) status(GRDVPNhelperConnectionObtainedNewCredential);
			}];
		}];
	}
	
	[[GRDGatewayAPI new] getServerStatusForHostname:[mainCredentials hostname] completion:^(NSError * _Nullable error) {
		if (error != nil) {
			[GRDCredentialManager clearMainCredentials];
			GRDErrorLogg(@"VPN server status check failed with error: %@", error);
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to validate server health of host '%@': %@", [mainCredentials hostname], error]]);
			return;
		}
		if (status) status(GRDVPNHelperConnectionEstablishingVPNTunnel);
		
		TransportProtocol transport = [mainCredentials transportProtocol];
		if (transport == TransportIKEv2) {
			[self _startIKEv2ConnectionForMainCredentials:mainCredentials withCompletion:completion];
			
		} else if (transport == TransportWireGuard) {
			[self _startWireGuardConnectionForMainCredentials:mainCredentials withCompletion:completion];
			
		} else {
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to start VPN tunnel for unknown transport protocol: %@", [GRDTransportProtocol transportProtocolStringFor:transport]]]);
			return;
		}
	}];
}


# pragma mark - Internal VPN Functions

+ (NSArray *)_vpnOnDemandRulesForMainCredentials:(GRDCredential *)mainCredential withProbeURL:(BOOL)probeURLEnabled disconnectOnEthernet:(BOOL)disconnectOnEthernet disconnectTrustedNetworks:(BOOL)disconntTrustedNetworks trustedNetworks:(NSArray<NSString *>  * _Nullable)trustedNetworks {
	// Create mutable array to throw on-demand rules into
	NSMutableArray *onDemandRules = [NSMutableArray new];
	
	// Create rule to disconnect the VPN automatically if the device is
	// connected to certain WiFi SSIDs.
	if (disconntTrustedNetworks == YES) {
		if (trustedNetworks != nil) {
			if ([trustedNetworks count] > 0) {
				NEOnDemandRuleDisconnect *disconnect 	= [NEOnDemandRuleDisconnect new];
				[disconnect setInterfaceTypeMatch:NEOnDemandRuleInterfaceTypeWiFi];
				[disconnect setSSIDMatch:trustedNetworks];
				[onDemandRules addObject:disconnect];
			}
		}
	}
	
#if TARGET_OS_MAC && !TARGET_OS_IPHONE || TARGET_OS_TV && !TARGET_OS_IPHONE
	// Create rule to disconnect the VPN tunnel automatically if the device
	// is connected to an ethernet connection
	if (disconnectOnEthernet == YES) {
		NEOnDemandRuleDisconnect *disconnect = [NEOnDemandRuleDisconnect new];
		[disconnect setInterfaceTypeMatch:NEOnDemandRuleInterfaceTypeEthernet];
		[onDemandRules addObject:disconnect];
	}
#endif
	
	// Create rule to connect to the VPN automatically if server reports that it is running OK
	// This is done by using the probe URL. It is a GET request which has to return 200 OK as the
	// HTTP response status code. No other indicator is considered and everything but 200 OK is
	// an automatic failure preventing the device to get stuck in a loop trying to connect
	NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
	vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
	if (probeURLEnabled == YES) {
		vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/v1.3/server-status/%@", mainCredential.hostname, mainCredential.clientId]];
	}
	
	[onDemandRules addObject:vpnServerConnectRule];
	return onDemandRules;
}

/// Starting the VPN connection via the builtin IKEv2 transport protocol
- (void)_startIKEv2ConnectionForMainCredentials:(GRDCredential *)mainCredentials withCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
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
			vpnManager.protocolConfiguration 	= [self _prepareIKEv2ParametersForServer:mainCredentials.server eapUsername:mainCredentials.username eapPasswordRef:mainCredentials.passwordRef withCertificateType:NEVPNIKEv2CertificateTypeECDSA256];
			
			NSString *finalLocalizedDescription = self.tunnelLocalizedDescription;
			if (self.appendServerRegionToTunnelLocalizedDescription == YES) {
				finalLocalizedDescription = [NSString stringWithFormat:@"%@: %@", self.tunnelLocalizedDescription, mainCredentials.hostnameDisplayValue];
			}
			vpnManager.localizedDescription = finalLocalizedDescription;
			
			if ([self onDemand]) {
				vpnManager.onDemandEnabled = YES;
				vpnManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesForMainCredentials:mainCredentials withProbeURL:!self.vpnKillSwitchEnabled disconnectOnEthernet:self.disconnectOnEthernet disconnectTrustedNetworks:self.disconnectOnTrustedNetworks trustedNetworks:self.trustedNetworks];
				
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
								self.currentTunnelManager = vpnManager;
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
        protocolConfig.includeAllNetworks = self.vpnKillSwitchEnabled;
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
- (void)_startWireGuardConnectionForMainCredentials:(GRDCredential *)mainCredentials withCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode, NSError * _Nullable))completion {
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
		NSString *wireGuardConfig = [GRDWireGuardConfiguration wireguardQuickConfigForCredential:mainCredentials smartProxyRoutingEnabled:[GRDVPNHelper smartProxyRoutingEnabled] dnsServers:self.preferredDNSServers];
		OSStatus saveStatus = [GRDKeychain storePassword:wireGuardConfig forAccount:kKeychainStr_WireGuardConfig];
		if (saveStatus != errSecSuccess) {
			if (completion) completion(GRDVPNHelperFail, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"[GRDTunnel] Failed to store WireGuard credentials in system keychain"]);
			return;
		}
		
		NETunnelProviderProtocol *protocol = [NETunnelProviderProtocol new];
		protocol.serverAddress 				= mainCredentials.hostname;
		protocol.providerBundleIdentifier 	= self.tunnelProviderBundleIdentifier;
		protocol.passwordReference 			= [GRDKeychain getPasswordRefForAccount:kKeychainStr_WireGuardConfig];
		protocol.username 					= [mainCredentials clientId];
		
		//
		// Note from CJ 2026-06-24
		// Disabling proxy settings for WireGuard connections here
		// to allow for testing of SRPv2 with WireGuard
//		protocol.proxySettings 				= [GRDVPNHelper proxySettingsForSGWServer:mainCredentials.server];
		
		if (@available(iOS 14.2, *)) {
			protocol.includeAllNetworks = self.vpnKillSwitchEnabled;
			protocol.excludeLocalNetworks = YES;
		}
		
		tunnelManager.protocolConfiguration = protocol;
		tunnelManager.enabled = YES;
		tunnelManager.onDemandEnabled = YES;
		tunnelManager.onDemandRules = [GRDVPNHelper _vpnOnDemandRulesForMainCredentials:mainCredentials withProbeURL:!self.vpnKillSwitchEnabled disconnectOnEthernet:self.disconnectOnEthernet disconnectTrustedNetworks:self.disconnectOnTrustedNetworks trustedNetworks:self.trustedNetworks];
		
		NSString *finalDescription = self.grdTunnelProviderManagerLocalizedDescription;
		if (self.appendServerRegionToGRDTunnelProviderManagerLocalizedDescription == YES) {
			finalDescription = [NSString stringWithFormat:@"%@: %@", self.grdTunnelProviderManagerLocalizedDescription, mainCredentials.hostnameDisplayValue];
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
				self.currentTunnelManager = tunnelManager;
				
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

- (void)disconnectVPNTunnelWithCompletion:(void (^)(NSError * _Nullable))completion {
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

- (void)forceDisconnectVPNTunnel {
	__block NEVPNStatus ikev2Status = [[[NEVPNManager sharedManager] connection] status];
	if (ikev2Status == NEVPNStatusConnected || ikev2Status == NEVPNStatusConnecting) {
		[self disconnectVPNTunnelWithCompletion:nil];

	} else if (ikev2Status == NEVPNStatusInvalid || ikev2Status == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			ikev2Status = [[[NEVPNManager sharedManager] connection] status];
			if (ikev2Status == NEVPNStatusConnected) {
				[self disconnectVPNTunnelWithCompletion:nil];
			}
		});
	}
	
	NETunnelProviderManager *tunnelManager = [self.tunnelManager tunnelProviderManager];
	__block NEVPNStatus wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
	if (wireguardStatus == NEVPNStatusConnected || wireguardStatus == NEVPNStatusConnecting) {
		[self disconnectVPNTunnelWithCompletion:nil];

	} else if (wireguardStatus == NEVPNStatusInvalid || wireguardStatus == NEVPNStatusReasserting) {
		// if its invalid we need to delay for a moment until our local instance is propagated with the proper connection info.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			wireguardStatus = [(NETunnelProviderSession *)tunnelManager.connection status];
			if (wireguardStatus == NEVPNStatusConnected) {
				[self disconnectVPNTunnelWithCompletion:nil];
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
	[defaults removeObjectForKey:kGRDDisconnectOnEthernet];
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
	BOOL expired = [subCred isExpired];
	// check current Subscriber Credential if it exists
	if (expired == YES || subCred == nil) {
		// No subscriber credential yet or it is expired. We have to create a new one
		GRDWarningLogg(@"No subscriber credential present or it has passed the safe expiration point");
		
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
			GRDPEToken *pet = [GRDPEToken currentPEToken];
			if (pet != nil) {
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
				if (completion) completion(nil, errorMessage);
				return;
				
			} else if (success == YES) {
				[GRDKeychain removeSubscriberCredentialWithRetries:3];
				OSStatus saveStatus = [GRDKeychain storePassword:subscriberCredential forAccount:kKeychainStr_SubscriberCredential];
				if (saveStatus != errSecSuccess) {
					if (completion) completion(nil, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Couldn't save subscriber credential in local keychain. Please try again."]);
					return;
				}
				
				GRDSubscriberCredential *subCred = [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subscriberCredential];
				GRDDebugLog(@"Successfully stored new Subscriber Credential: %@", subscriberCredential);
				if (completion) completion(subCred, nil);
			}
		}];
		
	} else {
		GRDDebugLog(@"Valid Subscriber Credential found: %@", subCred.jwt);
		if (completion) completion(subCred, nil);
	}
}

- (void)createStandaloneCredentialsForTransportProtocol:(TransportProtocol)protocol validForDays:(NSInteger)days server:(GRDSGWServer *)server completion:(void (^)(NSDictionary * credentials, NSError * error))completion {
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential *subscriberCredential, NSError *error) {
		if (subscriberCredential != nil) {
			
			NSArray *clientRules = [self apiPortableClientRules];
#warning fix this
			NSDictionary *deviceFilterConfigs = @{@"block-phishing": @(NO), @"block-ads": @(NO), @"block-none": @(NO)};
			NSString *exitRegion = [self preferredMultihopExitRegion];

			if (protocol == TransportIKEv2) {
				[[GRDGatewayAPI new] registerDeviceCredentialForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:server.hostname subscriberCredential:subscriberCredential.jwt transportOptions:@{} deviceFilterConfigs:deviceFilterConfigs clientRules:clientRules multihopExitRegion:exitRegion completion:^(NSDictionary * _Nullable credentialDetails, NSError * _Nullable error) {
					if (completion) completion(credentialDetails, nil);
				}];
				
			} else {
				GRDCurve25519 *keys = [[GRDCurve25519 alloc] init];
				[keys generateKeyPair];
				
				[[GRDGatewayAPI new] registerDeviceCredentialForTransportProtocol:[GRDTransportProtocol transportProtocolStringFor:protocol] hostname:server.hostname subscriberCredential:subscriberCredential.jwt transportOptions:@{@"public-key":keys.publicKey} deviceFilterConfigs:deviceFilterConfigs clientRules:clientRules multihopExitRegion:exitRegion completion:^(NSDictionary * _Nullable credentialDetails, NSError * _Nullable error) {
					if (error != nil) {
						if (completion) completion(nil, error);
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
	//
	// Note from CJ 2024-09-27
	// Yup, still going strong
	//
	// Note from CJ 2025-03-13
	// Tiny edit to remove things that
	// do not need to be part of the SDK
	//
	// Note from CJ 2026-02-03
	// Still going strong with this
	if ([subCred.subscriptionType isEqualToString:@"grd_trial_3_days"]) {
		eapCredentialsValidFor = 3;
	}
	return eapCredentialsValidFor;
}

# pragma mark - Credential Validation Helper

- (void)verifyMainCredentialsWithCompletion:(void(^)(BOOL valid, NSError * _Nullable error))completion {
	GRDCredential *mainCreds = [GRDCredentialManager mainCredentials];
	if (![mainCreds canSendSGWAPIRequests]) {
		if (completion) completion(NO, [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Main credential can't send SGW API requests"]);
		return;
	}
	
	[self getValidSubscriberCredentialWithCompletion:^(GRDSubscriberCredential * _Nullable subscriberCredential, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(NO, error);
			return;
		}
		
		[[GRDGatewayAPI new] verifyCredentialsForClientId:mainCreds.clientId withAPIToken:mainCreds.apiAuthToken hostname:mainCreds.hostname subscriberCredential:subscriberCredential.jwt completion:^(BOOL credentialsValid, NSError * _Nullable error) {
			if (error == nil) {
				if (credentialsValid == YES) {
					if (completion) completion(YES, nil);
					return;
				
				} else {
					if ([self isConnected] == NO) {
						[self forceDisconnectVPNTunnel];
						// Create a fresh set of credentials (new user) in our current region.
						GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
						[serverManager findBestHostInRegion:[self selectedRegion] completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
							[self configureUserFirstTimeForTransportProtocol:mainCreds.transportProtocol server:server connectionStatus:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable error) {
								if (completion) completion(YES, error);
							}];
						}];
					
					} else {
						if (completion) completion(NO, error);
						return;
					}
				}
				
			} else {
				if ([self isConnected] == NO) {
					[self forceDisconnectVPNTunnel];
					//create a fresh set of credentials (new user) in our current region.
					GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:self.serverFeatureEnvironment betaCapableServers:self.preferBetaCapableServers];
					[serverManager findBestHostInRegion:[self selectedRegion] completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
						[self configureUserFirstTimeForTransportProtocol:mainCreds.transportProtocol server:server connectionStatus:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable error) {
							if (error != nil) {
								if (completion) completion(NO, error);
								return;
							}
							
							if (completion) completion(YES, nil);
						}];
					}];
				
				} else {
					if (completion) completion(NO, error);
					return;
				}
			}
		}];
	}];
}

- (NSError * _Nullable)selectRegion:(GRDRegion * _Nullable)selectedRegion {
	self.selectedRegion = selectedRegion;
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
		
		//
		// Note from CJ 2024-11-06
		// Ensure that we remove the last known automatic routing mode
		// region that we had recorded so that we do not post
		// a time zone change notification to an integrating application
		// whenever the user changes time zones but has since set the routing
		// mode to a specific region
		[defaults removeObjectForKey:kGRDLastKnownAutomaticRegion];
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
	NSMutableArray <NSString *> *deduplicated = [NSMutableArray new];
	for (NSString *ssid in trustedNetworks) {
		if ([deduplicated containsObject:ssid] == NO) {
			[deduplicated addObject:ssid];
		}
	}
	
	NSUserDefaults *defaults 			= [NSUserDefaults standardUserDefaults];
	self.disconnectOnTrustedNetworks 	= enabled;
	self.trustedNetworks 				= trustedNetworks;
	
	if (enabled == NO) {
		[defaults removeObjectForKey:kGRDDisconnectOnTrustedNetworks];
		
	} else {
		[defaults setBool:enabled forKey:kGRDDisconnectOnTrustedNetworks];
	}
	
	if ([deduplicated count] < 1 || trustedNetworks == nil) {
		[defaults removeObjectForKey:kGRDTrustedNetworksArray];
		[defaults removeObjectForKey:kGRDDisconnectOnTrustedNetworks];
		
	} else {
		self.trustedNetworks = [NSArray arrayWithArray:deduplicated];
		[defaults setObject:deduplicated forKey:kGRDTrustedNetworksArray];
	}
}

- (void)setVPNKillSwitchEnabled:(BOOL)enabled {
	self.vpnKillSwitchEnabled = enabled;
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kGRDKillSwitchEnabled];
}

- (void)allRegionsWithCompletion:(void (^)(NSArray<GRDRegion *> * _Nullable, NSError * _Nullable))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:self.regionPrecision serverFeatureEnvironment:ServerFeatureEnvironmentProduction betaCapableServers:NO];
	[serverManager allRegionsWithCompletion:^(NSArray<GRDRegion *> * _Nullable regions, NSError * _Nullable errorMessage) {
		if (completion) completion(regions, errorMessage);
	}];
}

- (void)checkTimeZoneChanged {
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
			
			//
			// Note from CJ 2024-11-05
			// Upon notifying the app about the possible time zone change
			// the last know automatic region data should be deleted so
			// that we don't keep notifying the app about the same time zone change
			[defaults removeObjectForKey:kGRDLastKnownAutomaticRegion];
			
			if (self.timezoneChangedBlock) self.timezoneChangedBlock(YES, lastKnownAutomaticRegion, automaticRegion);
		}];
	}
}

- (void)clearLocalCache {
	[GRDLogger deleteAllLogs];
	[GRDKeychain removeGuardianKeychainItems];
	[GRDKeychain removeSubscriberCredentialWithRetries:3];
}

# pragma mark - Multihop

- (NSString *)preferredMultihopExitRegion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *preferredExitRegion = [defaults stringForKey:@"kGRDMultihopExitRegion"];
	
	return preferredExitRegion;
}

- (NSError *)setPreferredMultihopExitRegion:(NSString *)exitRegion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:exitRegion forKey:@"kGRDMultihopExitRegion"];
	
	__block NSError *multihopError;
	GRDCredential *mainCredential = [GRDCredentialManager mainCredentials];
	if ([mainCredential canSendSGWAPIRequests]) {
		[[GRDGatewayAPI new] setMultihopExitRegion:exitRegion hostname:[mainCredential hostname] deviceId:[mainCredential clientId] apiAuthToken:[mainCredential apiAuthToken] completion:^(NSDictionary * _Nullable multihopConfigs, NSError * _Nullable error) {
			if (error != nil) {
				multihopError = error;
			}
		}];
	}
	
	return multihopError;
}


#pragma mark - Client Rules

- (void)clientRulesWithCompletion:(void (^)(NSArray<GRDClientRule *> * _Nullable, NSError * _Nullable))completion {
	NSData *encodedClientRules = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDClientRulesList];
	if (encodedClientRules == nil) {
		if (completion) completion(nil, nil);
		return;
	}
	
	NSError *unarchiveErr;
	NSArray <GRDClientRule *> *clientRules = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSString class], [GRDClientRule class], nil] fromData:encodedClientRules error:&unarchiveErr];
	if (unarchiveErr != nil) {
		if (completion) completion(nil, unarchiveErr);
		return;
	}
	
	if (completion) completion(clientRules, nil);
}

- (NSInteger)indexOfClientRule:(GRDClientRule *)clientRule inAllRules:(NSArray <GRDClientRule *> *)allClientRules {
	NSInteger index = 0;
	for (GRDClientRule *rule in allClientRules) {
		if ([rule isEqual:clientRule]) {
			return index;
		}
		index++;
	}
	
	return -1;
}

- (NSError *)addClientRule:(GRDClientRule *)newClientRule {
	__block NSError *storeError = nil;
	[self clientRulesWithCompletion:^(NSArray<GRDClientRule *> * _Nullable clientRules, NSError * _Nullable error) {
		if (error != nil) {
			storeError = error;
			return;
		}
		
		NSMutableArray *mutableRules = [clientRules mutableCopy];
		if (mutableRules == nil) {
			mutableRules = [NSMutableArray new];
		}
		
		NSInteger index = [self indexOfClientRule:newClientRule inAllRules:mutableRules];
		if (index != -1) {
			[mutableRules replaceObjectAtIndex:index withObject:newClientRule];
			
		} else {
			[mutableRules addObject:newClientRule];
		}
		
		NSError *storeErr = [self storeClientRules:mutableRules];
		if (storeErr != nil) {
			storeError = storeErr;
			return;
		}
	}];
	
	return storeError;
}

- (NSError *)removeClientRule:(GRDClientRule *)clientRule {
	__block NSError *removeErr = nil;
	[self clientRulesWithCompletion:^(NSArray<GRDClientRule *> * _Nullable clientRules, NSError * _Nullable error) {
		if (error != nil) {
			removeErr = error;
			return;
		}
		
		if ([clientRules count] < 1) {
			return;
		}
		
		NSMutableArray *mutableClientRules = [clientRules mutableCopy];
		NSInteger index = [self indexOfClientRule:clientRule inAllRules:clientRules];
		if (index != -1) {
			removeErr = [GRDErrorHelper errorWithErrorCode:GRDErrGenericErrorCode andErrorMessage:@"The provided client rule does not exist"];
			return;
		}
		
		[mutableClientRules removeObjectAtIndex:index];
		NSError *storeErr = [self storeClientRules:mutableClientRules];
		if (storeErr != nil) {
			removeErr = storeErr;
			return;
		}
	}];
	
	return removeErr;
}

- (NSError *)storeClientRules:(NSArray <GRDClientRule *> *)clientRules {
	__block NSError *storeError;
	NSError *encodeErr;
	NSData *encodedClientRules = [NSKeyedArchiver archivedDataWithRootObject:clientRules requiringSecureCoding:YES error:&encodeErr];
	if (encodeErr != nil) {
		return encodeErr;
	}
	[[NSUserDefaults standardUserDefaults] setObject:encodedClientRules forKey:kGRDClientRulesList];
	
	GRDCredential *mainCredential = [GRDCredentialManager mainCredentials];
	if ([mainCredential canSendSGWAPIRequests]) {
		[[GRDGatewayAPI new] setClientRules:[self apiPortableClientRules] hostname:[mainCredential hostname] deviceId:[mainCredential clientId] apiAuthToken:[mainCredential apiAuthToken] completion:^(NSArray * _Nullable rulesRaw, NSError * _Nullable error) {
			if (error != nil) {
				storeError = error;
				return;
			}
		}];
	}
	
	return storeError;
}

- (NSArray *)apiPortableClientRules {
	__block NSMutableArray *requestData = [NSMutableArray new];
	[self clientRulesWithCompletion:^(NSArray<GRDClientRule *> * _Nullable clientRules, NSError * _Nullable error) {
		for (GRDClientRule *rule in clientRules) {
			if (rule.enabled == NO) continue;
			
			NSMutableDictionary *encodedRule = [NSMutableDictionary new];
			[encodedRule setObject:[GRDClientRule keyForMatchType:rule.matchType] forKey:@"match-type"];
//			[encodedRule setObject:[rule matchPort] forKey:@"match-port"];
			[encodedRule setObject:[rule matchValue] forKey:@"match-value"];
			//		[encodedRule setObject:[rule ruleId] forKey:@"rule-id"];
			[encodedRule setObject:[GRDClientRule keyForVerdict:rule.verdict] forKey:@"verdict"];
			//		[encodedRule setObject:[rule multihopExitRegion] forKey:@"multihop-exit-region"];
			
			[requestData addObject:encodedRule];
		}
	}];
	
	return requestData;
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
				[[GRDVPNHelper sharedInstance] connectVPNTunnelWithConnectionStatus:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable error) {
					if (status != GRDVPNHelperSuccess) {
						GRDErrorLogg(@"Failed to re-establish VPN connection after enabling Smart Proxy Routing:", error);
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
		[[GRDVPNHelper sharedInstance] connectVPNTunnelWithConnectionStatus:nil completion:^(GRDVPNHelperStatusCode status, NSError * _Nullable error) {
			if (status != GRDVPNHelperSuccess) {
				GRDErrorLogg(@"Failed to re-establish VPN connection after disabling Smart Proxy Routing:", error);
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
		proxySettings.proxyAutoConfigurationURL = [NSURL URLWithString:@"https://connect-api.guardianapp.com/api/v1/smart-proxy-routing/static-pac"];
		
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
		NSError *unarchiveErr;
		GRDBlocklistGroup *blocklistGroup = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[GRDBlocklistGroup class], [GRDBlocklistItem class], [NSString class], [NSArray class], [NSNumber class], nil] fromData:item error:&unarchiveErr];
		if (unarchiveErr != nil) {
			GRDErrorLogg(@"Failed to decode blocklist group object: %@", [unarchiveErr localizedDescription]);
			continue;
		}
		
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
		NSError *archiveErr;
		NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject:group requiringSecureCoding:YES error:&archiveErr];
		if (archiveErr != nil) {
			GRDErrorLogg(@"Failed to archive blocklist group data: %@", [archiveErr localizedDescription]);
			return;
		}
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
	
	NSError *archiveErr;
	[blocklistGroups insertObject:[NSKeyedArchiver archivedDataWithRootObject:blocklistGroupItem requiringSecureCoding:YES error:&archiveErr] atIndex:0];
	if (archiveErr != nil) {
		GRDErrorLogg(@"Failed to archive blocklist group: %@", [archiveErr localizedDescription]);
		return;
	}
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
		NSError *archiveErr;
        NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject:mergedGroup requiringSecureCoding:YES error:&archiveErr];
		if (archiveErr != nil) {
			GRDErrorLogg(@"Failed to archive blocklist group: %@", [archiveErr localizedDescription]);
			return;
		}
        [modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
    }
    [[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDBlocklistGroups];
}

+ (void)removeBlocklistGroup:(GRDBlocklistGroup *)blocklistGroupItem {
    if (!blocklistGroupItem) { return; }
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlocklistGroups];
    NSMutableArray<NSData *> *blocklistGroups = [NSMutableArray arrayWithArray:storedItems];
    if (blocklistGroups.count) {
		NSError *archiveErr;
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:blocklistGroupItem requiringSecureCoding:YES error:&archiveErr];
		if (archiveErr != nil) {
			GRDErrorLogg(@"Failed to archive blocklist group: %@", [archiveErr localizedDescription]);
			return;
		}
        [blocklistGroups removeObject:itemData];
        [[NSUserDefaults standardUserDefaults] setValue:blocklistGroups forKey:kGRDBlocklistGroups];
    }
}

+ (void)clearBlocklistData {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDBlocklistGroups];
}

@end
