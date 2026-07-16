//
//  GRDServer.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 20.03.24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import "GRDSGWServer.h"

@implementation GRDSGWServer

- (instancetype)initFromDictionary:(NSDictionary *)dict {
	self = [super init];
	if (self) {
		self.hostname = dict[@"hostname"];
		self.displayName = dict[@"display-name"];
		NSNumber *offlineNum = dict[@"offline"];
		self.offline = [offlineNum boolValue];
		
		NSNumber *capacityScoreNum = dict[@"capacity-score"];
		self.capacityScore = [capacityScoreNum integerValue];
		
		NSNumber *serverFeatureEnvNum = dict[@"server-feature-environment"];
		self.serverFeatureEnvironment = [serverFeatureEnvNum integerValue];
		
		NSNumber *betaCapableNum = dict[@"beta-capable"];
		self.betaCapable = [betaCapableNum boolValue];
		
		NSNumber *smartRoutingEnabledNum = dict[@"smart-routing-enabled"];
		self.smartRoutingProxyEnabled = [smartRoutingEnabledNum boolValue];
		
		self.ipv4Address = dict[@"ipv4-address"];
		self.ipv6Address = dict[@"ipv6-address"];
		self.region = [[GRDRegion alloc] initWithDictionary:dict[@"region"]];
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"hostname: %@; display-name: %@; offline: %@; smart-routing-enabled: %@; region-name: %@, region-pretty: %@, region-country: %@", self.hostname, self.displayName, self.offline ? @"YES" : @"NO", self.smartRoutingProxyEnabled ? @"YES" : @"NO", self.region.regionName, self.region.displayName, self.region.country];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super init];
	if (self) {
		self.hostname 					= [coder decodeObjectForKey:@"hostname"];
		self.displayName 				= [coder decodeObjectForKey:@"displayName"];
		self.offline 					= [coder decodeBoolForKey:@"offline"];
		self.capacityScore 				= [coder decodeIntegerForKey:@"capacityScore"];
		self.serverFeatureEnvironment 	= [coder decodeIntegerForKey:@"serverFeatureEnvironment"];
		self.betaCapable 				= [coder decodeBoolForKey:@"betaCapable"];
		self.smartRoutingProxyEnabled 	= [coder decodeBoolForKey:@"smartProxyRoutingEnabled"];
		self.ipv4Address				= [coder decodeObjectForKey:@"ipv4Address"];
		self.ipv6Address				= [coder decodeObjectForKey:@"ipv6Address"];
		self.region 					= [coder decodeObjectForKey:@"region"];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.hostname forKey:@"hostname"];
	[coder encodeObject:self.displayName forKey:@"displayName"];
	[coder encodeBool:self.offline forKey:@"offline"];
	[coder encodeInteger:self.capacityScore forKey:@"capacityScore"];
	[coder encodeInteger:self.serverFeatureEnvironment forKey:@"serverFeatureEnvironment"];
	[coder encodeBool:self.betaCapable forKey:@"betaCapable"];
	[coder encodeBool:self.smartRoutingProxyEnabled forKey:@"smartProxyRoutingEnabled"];
	[coder encodeObject:self.ipv4Address forKey:@"ipv4Address"];
	[coder encodeObject:self.ipv6Address forKey:@"ipv6Address"];
	[coder encodeObject:self.region forKey:@"region"];
}

- (NSString *)addressForStealthModeEnabled:(BOOL)stealthModeEnabled {
	NSString *hostname = self.hostname;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// MITIGATION (GRD-1391): with Stealth Mode OFF we MUST return the FQDN unchanged so behaviour is
	// byte-for-byte identical to before this feature existed. Only override the dial target when the
	// user has explicitly opted in.
	if (stealthModeEnabled == NO) {
		return hostname;
	}
	
	if (hostname == nil || hostname.length == 0) {
		return hostname;
	}
	
	NSDictionary<NSString *, NSString *> *ipMap = [defaults dictionaryForKey:kGRDStealthSGWIPCache];
	NSString *cachedIP = ipMap[hostname];
	
	// MITIGATION (GRD-1391): on a cache miss fall back to the FQDN rather than failing the connection.
	// Worst case the user is no worse off than with Stealth Mode disabled.
	if ([cachedIP isKindOfClass:[NSString class]] == NO || cachedIP.length == 0) {
		GRDWarningLogg(@"[Stealth] No cached IP for hostname '%@'; falling back to FQDN dial target", hostname);
		return hostname;
	}
	
	GRDDebugLog(@"[Stealth] Dialling '%@' by direct IP '%@'", hostname, cachedIP);
	return cachedIP;
}

@end
