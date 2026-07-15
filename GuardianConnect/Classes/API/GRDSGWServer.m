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
		// Stealth Mode (GRD-1391): forward-compatible parse of a direct server IP if the
		// backend ever includes it inline in the server list. In v1 this is normally nil
		// because IPs are sourced from the separately-cached sgw-ips map; nil is fine and
		// callers fall back to `hostname`.
		self.serverIPv4 = dict[@"ipv4"];
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
		self.smartProxyRoutingEnabled = [smartRoutingEnabledNum boolValue];
		
		self.ipv4Address = dict[@"ipv4-address"];
		self.ipv6Address = dict[@"ipv6-address"];
		self.region = [[GRDRegion alloc] initWithDictionary:dict[@"region"]];
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"hostname: %@; display-name: %@; offline: %@; smart-routing-enabled: %@; region-name: %@, region-pretty: %@, region-country: %@", self.hostname, self.displayName, self.offline ? @"YES" : @"NO", self.smartProxyRoutingEnabled ? @"YES" : @"NO", self.region.regionName, self.region.displayName, self.region.country];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super init];
	if (self) {
		self.hostname 					= [coder decodeObjectForKey:@"hostname"];
		self.serverIPv4 				= [coder decodeObjectForKey:@"serverIPv4"]; // GRD-1391
		self.displayName 				= [coder decodeObjectForKey:@"displayName"];
		self.offline 					= [coder decodeBoolForKey:@"offline"];
		self.capacityScore 				= [coder decodeIntegerForKey:@"capacityScore"];
		self.serverFeatureEnvironment 	= [coder decodeIntegerForKey:@"serverFeatureEnvironment"];
		self.betaCapable 				= [coder decodeBoolForKey:@"betaCapable"];
		self.smartProxyRoutingEnabled 	= [coder decodeBoolForKey:@"smartProxyRoutingEnabled"];
		self.ipv4Address				= [coder decodeObjectForKey:@"ipv4Address"];
		self.ipv6Address				= [coder decodeObjectForKey:@"ipv6Address"];
		self.region 					= [coder decodeObjectForKey:@"region"];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.hostname forKey:@"hostname"];
	[coder encodeObject:self.serverIPv4 forKey:@"serverIPv4"]; // GRD-1391
	[coder encodeObject:self.displayName forKey:@"displayName"];
	[coder encodeBool:self.offline forKey:@"offline"];
	[coder encodeInteger:self.capacityScore forKey:@"capacityScore"];
	[coder encodeInteger:self.serverFeatureEnvironment forKey:@"serverFeatureEnvironment"];
	[coder encodeBool:self.betaCapable forKey:@"betaCapable"];
	[coder encodeBool:self.smartProxyRoutingEnabled forKey:@"smartProxyRoutingEnabled"];
	[coder encodeObject:self.ipv4Address forKey:@"ipv4Address"];
	[coder encodeObject:self.ipv6Address forKey:@"ipv6Address"];
	[coder encodeObject:self.region forKey:@"region"];
}

@end
