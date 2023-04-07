//
//  GRDPEToken.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 15.03.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDPEToken.h"

@implementation GRDPEToken

- (instancetype)initFromDictionary:(NSDictionary *)dict {
	self = [super init];
	if (self) {
		self.token = [dict objectForKey:@"pe-token"];
		
		NSNumber *expirationDateUnix = [dict objectForKey:@"pet-expires"];
		self.expirationDate = [NSDate dateWithTimeIntervalSince1970:[expirationDateUnix integerValue]];
		self.expirationDateUnix = [expirationDateUnix integerValue];
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"[GRDPEToken] \rtoken: %@ \rexpiration-date: %@ (unix: %ld)", self.token, self.expirationDate, self.expirationDateUnix];
}


+ (GRDPEToken *)currentPEToken {
	NSString *petString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
	if (petString == nil || [petString isEqualToString:@""]) {
		return nil;
	}
	
	NSNumber *petExpires = [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:kGuardianPETokenExpirationDate]];
	
	GRDPEToken *pet = [GRDPEToken new];
	[pet setToken:petString];
	[pet setExpirationDate:[NSDate dateWithTimeIntervalSince1970:[petExpires integerValue]]];
	[pet setExpirationDateUnix:[petExpires integerValue]];
	
	return pet;
}

- (BOOL)isExpired {
	BOOL expired = NO;
	if ([[NSDate date] timeIntervalSince1970] > self.expirationDateUnix) {
		expired = YES;
	}
	
	return expired;
}

- (BOOL)requiresValidation {
	BOOL expired = [self isExpired];
	if (expired == YES) {
		return YES;
	}
	
	NSDateComponents *dateComp = [NSDateComponents new];
	[dateComp setDay:7];
	NSDate *validationThreshold = [[NSCalendar currentCalendar] dateByAddingComponents:dateComp toDate:[NSDate date] options:0];
	if ([validationThreshold timeIntervalSince1970] > self.expirationDateUnix) {
		return YES;
	}
	
	return NO;
}

- (NSError *)store {
	OSStatus storeStatus = [GRDKeychain storePassword:self.token forAccount:kKeychainStr_PEToken];
	if (storeStatus != errSecSuccess) {
		return [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Failed to store PE-Token in the local keychain"];
	}
	
	[[NSUserDefaults standardUserDefaults] setInteger:self.expirationDateUnix forKey:kGuardianPETokenExpirationDate];
	
	return nil;
}

- (NSError *)destroy {
	OSStatus deleteStatus = [GRDKeychain removeKeychainItemForAccount:kKeychainStr_PEToken];
	if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
		return [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Failed to delete PE-Token from the local keychain"];
	}
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kGuardianPETokenExpirationDate];
	
	return nil;
}

@end
