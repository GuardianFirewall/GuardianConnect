//
//  GRDAPIError.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDAPIError.h"

@implementation GRDAPIError

- (NSString *)description {
	return [NSString stringWithFormat:@"status-code: %ld; error-title: %@; error-message: '%@'", self.statusCode, self.title, self.message];
}

- (instancetype)initWithData:(NSData *)jsonData andStatusCode:(NSInteger)statusCode {
	self = [super init];
	if (self) {
		self.statusCode = statusCode;
		if (jsonData == nil) {
			self.title 		= @"Failed to parse error";
			self.message 	= @"Failed to parse the API error message returned by the server";
			
		} else {
			NSError *jsonErr;
			self.apiErrorDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonErr];
			if (jsonErr != nil) {
				self.jsonParseError = jsonErr;
				self.title 			= @"JSON Parse Error";
				self.message 		= [NSString stringWithFormat:@"Failed to parse JSON API error message data: %@", jsonErr];
				
			} else {
				self.title 		= [self.apiErrorDictionary objectForKey:@"error-title"];
				self.message 	= [self.apiErrorDictionary objectForKey:@"error-message"];
			}
		}
	}
	
	return self;
}

@end
