//
//  GRDSubscriberCredential.m
//  Guardian
//
//  Created by Constantin Jacob on 11.05.20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDSubscriberCredential.h>

@implementation GRDSubscriberCredential

- (instancetype)initWithSubscriberCredential:(NSString *)subscriberCredential {
    if (!subscriberCredential) return nil; //if theres no subscriber credential string we dont want to create the credential!
    if (!self) {
        self = [super init];
    }
	
    self.jwt = subscriberCredential;
	
	NSArray *jwtComp = [self.jwt componentsSeparatedByString:@"."];
	if ([jwtComp count] < 1) {
		GRDErrorLogg(@"Trying to process invalid Subscriber Credential (JWT): %@", self.jwt);
		return nil;
	}
	NSString *payloadString = [jwtComp objectAtIndex:1];
	
	payloadString = [payloadString stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
	payloadString = [payloadString stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
	
	// Figuring out how many buffer characters we're missing
	int size = [payloadString length] % 4;
	
	// Creating a mutable string from the payloadString
	NSMutableString *base64String = [[NSMutableString alloc] initWithString:payloadString];
	
	// Adding as many buffer '=' (equal sign) characters as is required to
	// make the payloadString divisble by 4 to make it base64 spec
	// compliant so that NSData will accept it and decode it
	// without silently failing
	for (int i = 0; i < size; i++) {
		[base64String appendString:@"="];
	}
	
	NSData *payload = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
	NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
	self.subscriptionType = [dict objectForKey:@"subscription-type"];
	self.subscriptionTypePretty = [dict objectForKey:@"subscription-type-pretty"];
	self.subscriptionExpirationDate = [(NSNumber*)[dict objectForKey:@"subscription-expiration-date"] integerValue];
	self.tokenExpirationDate = [(NSNumber*)[dict objectForKey:@"exp"] integerValue];
	
    return self;
}

- (NSString *)description {
	NSString *desc = [super description];
	
	NSString *expiredString = @"YES";
	if ([self isExpired] == NO) {
		expiredString = @"NO";
	}
	
	return [NSString stringWithFormat:@"%@ \nSubscription Type: %@ \nSubscription Expiration Date: %@; \nToken Expiration Date: %@; \nExpired: %@", desc, self.subscriptionType, [NSDate dateWithTimeIntervalSince1970:self.subscriptionExpirationDate], [NSDate dateWithTimeIntervalSince1970:self.tokenExpirationDate], expiredString];
}

+ (GRDSubscriberCredential * _Nullable )currentSubscriberCredential {
	NSString *subCredString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential];
	return [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subCredString];
}

- (BOOL)isExpired {
	static NSUInteger 	twoDays 						= 172800;
	NSTimeInterval 		safeSubscriptionExpirationDate 	= self.subscriptionExpirationDate - twoDays;
	NSTimeInterval 		safeTokenExpirationDate 		= self.tokenExpirationDate - twoDays;
	NSTimeInterval 		nowUnixTimestamp				= [[NSDate date] timeIntervalSince1970];
	
	if (safeSubscriptionExpirationDate < nowUnixTimestamp || safeTokenExpirationDate < nowUnixTimestamp) {
		return YES;
	}
	
	return NO;
}

+ (void)setPreferredValidationMethod:(GRDHousekeepingValidationMethod)validationMethod {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (validationMethod == ValidationMethodInvalid) {
		[defaults removeObjectForKey:kGuardianPreferredSubscriberCredentialValidationMethod];
		
	} else {
		[defaults setInteger:validationMethod forKey:kGuardianPreferredSubscriberCredentialValidationMethod];
	}
}

+ (GRDHousekeepingValidationMethod)getPreferredValidationMethod {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults objectForKey:kGuardianPreferredSubscriberCredentialValidationMethod] == nil) {
		return ValidationMethodInvalid;
	}
	
	GRDHousekeepingValidationMethod valMethod = [[NSUserDefaults standardUserDefaults] integerForKey:kGuardianPreferredSubscriberCredentialValidationMethod];
	return valMethod;
}

@end
