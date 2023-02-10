//
//  GRDConnectSubscriber.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDConnectSubscriber.h"

@implementation GRDConnectSubscriber

- (instancetype)initFromDictionary:(NSDictionary * _Nonnull)dict {
	self = [super init];
	if (self) {
		self.identifier = [dict objectForKey:kGuardianConnectSubscriberIdentifierKey];
		self.email = [dict objectForKey:kGuardianConnectSubscriberEmailKey];
		self.subscriptionSKU = [dict objectForKey:kGuardianConnectSubscriberSubscriptionSKUKey];
		self.subscriptionNameFormmated = [dict objectForKey:kGuardianConnectSubscriberSubscriptionNameFormattedKey];
		
		NSNumber *expirationDateUnix = [dict objectForKey:kGuardianConnectSubscriberSubscriptionExpirationDateKey];
		self.subscriptionExpirationDate = [NSDate dateWithTimeIntervalSince1970:[expirationDateUnix integerValue]];
		
		NSNumber *createdAtDateUnix = [dict objectForKey:kGuardianConnectSubscriberCreatedAtKey];
		self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdAtDateUnix integerValue]];
	}
	
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super init];
	if (self) {
		self.identifier = [coder decodeObjectForKey:kGuardianConnectSubscriberIdentifierKey];
		self.email = [coder decodeObjectForKey:kGuardianConnectSubscriberEmailKey];
		self.subscriptionSKU = [coder decodeObjectForKey:kGuardianConnectSubscriberSubscriptionSKUKey];
		self.subscriptionNameFormmated = [coder decodeObjectForKey:kGuardianConnectSubscriberSubscriptionNameFormattedKey];
		
		NSNumber *expirationDateUnix = [coder decodeObjectForKey:kGuardianConnectSubscriberSubscriptionExpirationDateKey];
		self.subscriptionExpirationDate = [NSDate dateWithTimeIntervalSince1970:[expirationDateUnix integerValue]];
		
		NSNumber *createdAtUnix = [coder decodeObjectForKey:kGuardianConnectSubscriberCreatedAtKey];
		self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdAtUnix integerValue]];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.identifier forKey:kGuardianConnectSubscriberIdentifierKey];
	[coder encodeObject:self.email forKey:kGuardianConnectSubscriberEmailKey];
	[coder encodeObject:self.subscriptionSKU forKey:kGuardianConnectSubscriberSubscriptionSKUKey];
	[coder encodeObject:self.subscriptionNameFormmated forKey:kGuardianConnectSubscriberSubscriptionNameFormattedKey];
	
	NSNumber *subscriptionExpirationDateUnix = [NSNumber numberWithDouble:[self.subscriptionExpirationDate timeIntervalSince1970]];
	[coder encodeObject:subscriptionExpirationDateUnix forKey:kGuardianConnectSubscriberSubscriptionExpirationDateKey];
	
	NSNumber *createdAtUnix = [NSNumber numberWithDouble:[self.createdAt timeIntervalSince1970]];
	[coder encodeObject:createdAtUnix forKey:kGuardianConnectSubscriberCreatedAtKey];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

+ (void)currentSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable, NSError * _Nullable))completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *subscriberDict = [defaults objectForKey:kGuardianConnectSubscriber];

	NSError *unarchiveErr;
	GRDConnectSubscriber *subscriber = [NSKeyedUnarchiver unarchivedObjectOfClass:[GRDConnectSubscriber class] fromData:subscriberDict error:&unarchiveErr];
	
	if (completion) completion(subscriber, nil);
}

- (BOOL)loadSecretFromKeychain {
	BOOL success = NO;
	NSString *secret = [GRDKeychain getPasswordStringForAccount:kGuardianConnectSubscriberSecret];
	if (secret != nil) {
		success = YES;
		self.secret = secret;
	}
	
	return success;
}

- (NSError *)store {
	NSError *archiveErr;
	NSData *subscriberData = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&archiveErr];
	if (archiveErr != nil) {
		return archiveErr;
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:subscriberData forKey:kGuardianConnectSubscriber];
	return nil;
}

- (void)allDevicesWithCompletion:(void (^)(NSArray<GRDConnectDevice *> * _Nullable, NSString * _Nullable))completion {
	NSString *peToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
	if (peToken == nil || [peToken isEqualToString:@""]) {
		if (completion) completion(nil, NSLocalizedString(@"Unable to fetch devices. No PE-Token available", nil));
		return;
	}
	
	[GRDConnectDevice listConnectDevicesForPEToken:peToken withCompletion:^(NSArray<GRDConnectDevice *> * _Nullable devices, NSString * _Nullable errorMessage) {
		if (completion) completion(devices, errorMessage);
		return;
	}];
}


# pragma mark - API Wrappers

- (void)registerNewConnectSubscriber:(BOOL)acceptedTOS withCompletion:(void (^)(GRDConnectSubscriber * _Nullable newSubscriber, NSString * _Nullable errorMessage))completion {
	[[GRDHousekeepingAPI new] newConnectSubscriberWith:self.identifier secret:self.secret acceptedTOS:acceptedTOS email:self.email andCompletion:^(NSDictionary * _Nullable subscriberDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectSubscriber *newSubscriber = [[GRDConnectSubscriber alloc] initFromDictionary:subscriberDetails];
		NSError *storeErr = [newSubscriber store];
		if (storeErr != nil) {
			if (completion) completion(nil, [NSString stringWithFormat:@"Failed to store persistent local data of new Connect Subscriber: %@", [storeErr localizedDescription]]);
			return;
		}
		
		if (completion) completion(newSubscriber, nil);
		return;
	}];
}

- (void)updateConnectSubscriberWithEmailAddress:(NSString * _Nonnull)email andCompletion:(void (^)(GRDConnectSubscriber * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] updateConnectSubscriberWith:self.email identifier:self.identifier secret:self.secret andCompletion:^(NSDictionary * _Nullable subscriberDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectSubscriber *subscriber = [[GRDConnectSubscriber alloc] initFromDictionary:subscriberDetails];
		NSError *updateErr = [subscriber store];
		if (updateErr != nil) {
			if (completion) completion(nil, [NSString stringWithFormat:@"Failed to store persistent local data of updated Connect Subscriber: %@", [updateErr localizedDescription]]);
			return;
		}
		
		if (completion) completion(subscriber, nil);
		return;
	}];
}

- (void)validateConnectSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] validateConnectSubscriberWith:self.identifier secret:self.secret andCompletion:^(NSDictionary * _Nullable details, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectSubscriber *newSubscriber = [self mutableCopy];
		newSubscriber.subscriptionSKU = [details objectForKey:kGuardianConnectSubscriberSubscriptionSKUKey];
		newSubscriber.subscriptionNameFormmated = [details objectForKey:kGuardianConnectSubscriberSubscriptionNameFormattedKey];
		
		NSNumber *subscriptionExpirationDateUnix = [details objectForKey:kGuardianConnectSubscriberSubscriptionExpirationDateKey];
		newSubscriber.subscriptionExpirationDate = [NSDate dateWithTimeIntervalSince1970:[subscriptionExpirationDateUnix integerValue]];
		
		NSString *pet = [details objectForKey:@"pe-token"];
		if (pet == nil || [pet isEqualToString:@""]) {
			if (completion) completion(nil, [NSString stringWithFormat:@"Failed to validate Connect Subscriber. No new PE-Token was returned"]);
			return;
		}
		
		OSStatus storeStatus = [GRDKeychain storePassword:pet forAccount:kKeychainStr_PEToken];
		if (storeStatus != errSecSuccess) {
			if (completion) completion(nil, [NSString stringWithFormat:@"Failed to store new PE-Token for Connect subscriber. Keychain status: %d", storeStatus]);
			return;
		}
		
		NSError *updateErr = [newSubscriber store];
		if (updateErr != nil) {
			if (completion) completion(nil, [NSString stringWithFormat:@"Failed to store persistent local data of validated Connect Subscriber: %@", [updateErr localizedDescription]]);
			return;
		}
		
		if (completion) completion(newSubscriber, nil);
		return;
	}];
}

@end
