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
		self.smartRoutingEnabled = [smartRoutingEnabledNum boolValue];
		self.region = [[GRDRegion alloc] initWithDictionary:dict[@"region"]];
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"hostname: %@; display-name: %@; offline: %@; smart-routing-enabled: %@; region-name: %@, region-pretty: %@, region-country: %@", self.hostname, self.displayName, self.offline ? @"YES" : @"NO", self.smartRoutingEnabled ? @"YES" : @"NO", self.region.regionName, self.region.displayName, self.region.country];
}



@end
