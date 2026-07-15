//
//  GRDAlert.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 09.07.26.
//  Copyright © 2026 Sudo Security Group Inc. All rights reserved.
//

#import "GRDAlert.h"

@implementation GRDAlert

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
	self = [super init];
	if (self) {
		NSString *action = dictionary[@"action"];
		if ([action isKindOfClass:[NSNull class]]) {
			[self setAction:@"drop"];
			
		} else {
			[self setAction:action];
		}
		
		NSString *category = dictionary[@"category"];
		[self setCategory:category];
		
		NSString *host = dictionary[@"host"];
		[self setHost:host];
		
		NSUInteger timestamp = [dictionary[@"timestamp"] integerValue];
		[self setTimestamp:timestamp];
		[self setBlockDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
		
		NSString *title = dictionary[@"title"];
		[self setTitle:title];
		
		NSString *message = dictionary[@"message"];
		[self setMessage:message];
		
		NSString *uuid = dictionary[@"uuid"];
		[self setIdentifier:uuid];
	}
	
	return self;
}

@end
