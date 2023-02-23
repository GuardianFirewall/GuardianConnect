//
//  GRDErrorHelper.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 23.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDErrorHelper.h"

@implementation GRDErrorHelper

+ (NSError *)errorWithErrorCode:(NSInteger)code andErrorMessage:(NSString *)errorMessage {
	NSDictionary *errorDict = @{NSLocalizedDescriptionKey: errorMessage};
	NSError *error = [NSError errorWithDomain:kGRDErrorDomainGeneral code:code userInfo:errorDict];
	return error;
}

@end
