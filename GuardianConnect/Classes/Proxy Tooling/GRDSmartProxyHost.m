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



@end
