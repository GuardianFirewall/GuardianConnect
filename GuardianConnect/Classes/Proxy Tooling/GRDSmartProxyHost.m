//
//  GRDSmartProxyHost.m
//  GuardianCore
//
//  Created by Constantin Jacob on 01.09.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDSmartProxyHost.h"
#import <GuardianConnect/GRDVPNHelper.h>

@implementation GRDSmartProxyHost

- (instancetype)initFromDictionary:(NSDictionary *)host {
	self = [super init];
	if (self) {
		self.host = host[@"host"];
		self.region = host[@"region"];
		self.requiresCorrelation = [host[@"requires-correlation"] boolValue];
	}
	
	return self;
}

+ (void)setupSmartProxyHosts:(void (^)(NSError * _Nullable))completion {
	[GRDSmartProxyHost requestAllSmartProxyHostsWithCompletion:^(NSArray<GRDSmartProxyHost *> * _Nullable hosts, NSError * _Nullable error) {
		if (error != nil) {
			if (completion) completion(error);
			
		} else {
			[[GRDVPNHelper sharedInstance] setSmartProxyRoutingHosts:hosts];
			if (completion) completion(nil);
		}
	}];
}

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

@end
