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
	return [NSString stringWithFormat:@"[GRDPEToken] \rtoken: %@ \rconnect-api-env: %@ \rexpiration-date: %@ (unix: %ld)", self.token, self.connectAPIEnv, self.expirationDate, self.expirationDateUnix];
}


+ (GRDPEToken *)currentPEToken {
	NSString *petString = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
	if (petString == nil || [petString isEqualToString:@""]) {
		return nil;
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *connectAPIEnv = [defaults stringForKey:kGuardianPETConnectAPIEnv];
	if (connectAPIEnv == nil || [connectAPIEnv isEqualToString:@""]) {
		connectAPIEnv = kConnectAPIHostname;
	}
	NSDate *petExpires = [defaults objectForKey:kGuardianPETokenExpirationDate];
	
	GRDPEToken *pet = [GRDPEToken new];
	[pet setToken:petString];
	[pet setConnectAPIEnv:connectAPIEnv];
	[pet setExpirationDate:petExpires];
	[pet setExpirationDateUnix:[petExpires timeIntervalSince1970]];
	
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
		return [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to store PE-Token in the local keychain. Keychain error code: %d", storeStatus]];
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:self.connectAPIEnv forKey:kGuardianPETConnectAPIEnv];
	[defaults setObject:self.expirationDate forKey:kGuardianPETokenExpirationDate];
	
	return nil;
}

- (NSError *)destroy {
	OSStatus deleteStatus = [GRDKeychain removeKeychainItemForAccount:kKeychainStr_PEToken];
	if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
		return [GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:[NSString stringWithFormat:@"Failed to delete PE-Token from the local keychain. Keychain error code: %d", deleteStatus]];
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:kGuardianPETConnectAPIEnv];
	[defaults removeObjectForKey:kGuardianPETokenExpirationDate];
	
	return nil;
}

@end
