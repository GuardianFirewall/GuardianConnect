//
//  GRDSubscriberCredential.m
//  Guardian
//
//  Created by Constantin Jacob on 11.05.20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDSubscriberCredential.h>
#import <GuardianConnect/GRDVPNHelper.h>

@implementation GRDSubscriberCredential

- (instancetype)initWithSubscriberCredential:(NSString *)subscriberCredential {
    if (!subscriberCredential) return nil; //if theres no subscriber credential string we dont want to create the credential!
    if (!self) {
        self = [super init];
    }
    self.jwt = subscriberCredential;
    [self processSubscriberCredentialInformation];
    return self;
}

- (NSString *)description {
	NSString *desc = [super description];
	
	NSString *expiredString = @"YES";
	if (self.tokenExpired == NO) {
		expiredString = @"NO";
	}
	
	return [NSString stringWithFormat:@"%@ \nSubscription Type: %@ \nSubscription Expiration Date: %@ \nExpired: %@", desc, self.subscriptionType, [NSDate dateWithTimeIntervalSince1970:self.subscriptionExpirationDate], expiredString];
}

- (void)processSubscriberCredentialInformation {
    if (self.jwt == nil) {
        return;
    }
    
    NSArray *jwtComp = [self.jwt componentsSeparatedByString:@"."];
    NSString *payloadString = [jwtComp objectAtIndex:1];
    
    // Note from CJ:
    // This is Base64 magic that I only partly understand because I am not entirely familiar with
    // the Base64 spec.
    // This just makes sure that the string can be read by removing invalid characters
    payloadString = [[payloadString stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    // Figuring out how many buffer characters we're missing
    int size = [payloadString length] % 4;
    
    // Creating a mutable string from the payloadString
    NSMutableString *base64String = [[NSMutableString alloc] initWithString:payloadString];
    
    // Adding as many buffer = as required to make the payloadString divisble by 4 to make
    // it Base64 spec compliant so that NSData will accept it and decode it
    for (int i = 0; i < size; i++) {
        [base64String appendString:@"="];
    }
    
    NSData *payload = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:payload options:0 error:nil];
    self.subscriptionType = [dict objectForKey:@"subscription-type"];
    self.subscriptionTypePretty = [dict objectForKey:@"subscription-type-pretty"];
    self.subscriptionExpirationDate = [(NSNumber*)[dict objectForKey:@"subscription-expiration-date"] integerValue];
    self.tokenExpirationDate = [(NSNumber*)[dict objectForKey:@"exp"] integerValue];
    self.tokenExpired = [self isExpired];
}

- (BOOL)isExpired {
	NSTimeInterval safeExpirationDate = [[[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitDay value:-2 toDate:[NSDate date] options:0] timeIntervalSince1970];
	NSTimeInterval jwtExpirationDate = self.tokenExpirationDate;
	return (safeExpirationDate > jwtExpirationDate);
}

+ (GRDSubscriberCredential * _Nullable )currentSubscriberCredential {
	NSString *subCredString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_SubscriberCredential];
	return [[GRDSubscriberCredential alloc] initWithSubscriberCredential:subCredString];
}

@end
