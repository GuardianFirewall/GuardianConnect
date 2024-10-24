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
		self.smartProxyRoutingEnabled = [smartRoutingEnabledNum boolValue];
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
		self.displayName 				= [coder decodeObjectForKey:@"displayName"];
		self.offline 					= [coder decodeBoolForKey:@"offline"];
		self.capacityScore 				= [coder decodeIntegerForKey:@"capacityScore"];
		self.serverFeatureEnvironment 	= [coder decodeIntegerForKey:@"serverFeatureEnvironment"];
		self.betaCapable 				= [coder decodeBoolForKey:@"betaCapable"];
		self.smartProxyRoutingEnabled 	= [coder decodeBoolForKey:@"smartProxyRoutingEnabled"];
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
	[coder encodeBool:self.smartProxyRoutingEnabled forKey:@"smartProxyRoutingEnabled"];
	[coder encodeObject:self.region forKey:@"region"];
}

@end
