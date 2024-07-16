//
//  GRDCredentialManager.m
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDCredentialManager.h"
#import "GRDServerManager.h"
#import "GRDVPNHelper.h"

@implementation GRDCredentialManager

+ (NSArray <GRDCredential *>*)credentials {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	NSArray *items = [NSKeyedUnarchiver unarchiveObjectWithData:[GRDKeychain getDataForAccount:kGuardianCredentialsList]];
	NSMutableArray<GRDCredential*> *credentials = [NSMutableArray array];
	for (NSData *item in items) {
		if ([item class] != [GRDCredential class]) {
			GRDCredential *credential = [NSKeyedUnarchiver unarchiveObjectWithData:item];
#pragma clang diagnostic pop
			[credentials addObject:credential];
		
		} else {
			[credentials addObject:(GRDCredential *)item];
		}
	}
	return credentials;
}

+ (NSArray <GRDCredential *>*)filteredCredentials { //credentials minus the main credentials, for use in EAP view
	NSArray *items = [self credentials];
	NSMutableArray<GRDCredential*> *credentials = [NSMutableArray array];
	for (GRDCredential *item in items) {
		if (![item mainCredential]) {
			[credentials addObject:item];
		}
	}
	return credentials;
}

+ (GRDCredential *)mainCredentials {
    NSArray *creds = [self credentials];
    return [[creds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"mainCredential == true"]] firstObject];
}

+ (void)clearMainCredentials {
    GRDCredential *main = [self mainCredentials];
    if (main) {
        [self removeCredential:main];
    }
}

+ (GRDCredential *)credentialWithIdentifier:(NSString *)identifier {
	NSArray <GRDCredential*> *credentials = [self credentials];
	return [[credentials filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]] lastObject];
}

+ (void)addOrUpdateCredential:(GRDCredential *)credential {
	if (!credential) { return; }
	NSMutableArray *credentialList = [NSMutableArray arrayWithArray:[self credentials]];
	if (!credentialList.count) {
		credentialList = [NSMutableArray array];
	}
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	NSData *newObject = [NSKeyedArchiver archivedDataWithRootObject:credential];

	GRDCredential *foundCred = [self credentialWithIdentifier:credential.identifier];
	if (foundCred) {
		NSArray *creds = [self credentials];
		NSInteger index = [creds indexOfObject:foundCred];
		if (index != NSNotFound) {
			[credentialList replaceObjectAtIndex:index withObject:newObject];
			
		} else {
			//should NOT happen...
			[credentialList insertObject:newObject atIndex:0];
		}
		
	} else {
		[credentialList insertObject:newObject atIndex:0];
	}
	
	if (credential.mainCredential == YES) {
		OSStatus status = [GRDKeychain storePassword:credential.password forAccount:credential.identifier];
		if (status != errSecSuccess) {
			[NSThread sleepForTimeInterval:2];
			[GRDKeychain storePassword:credential.password forAccount:credential.identifier];
		}
		credential.passwordRef = [GRDKeychain getPasswordRefForAccount:credential.identifier];
	}
	
	[GRDKeychain storeData:[NSKeyedArchiver archivedDataWithRootObject:credentialList] forAccount:kGuardianCredentialsList];
#pragma clang diagnostic pop
}

+ (void)removeCredential:(GRDCredential *)credential {
    if (!credential) return;
	
	// Ensure that the passwordref required for IKEv2 is removed as well
	if (credential.mainCredential == YES && credential.transportProtocol == TransportIKEv2) {
		OSStatus deleteStatus = [GRDKeychain removeKeychainItemForAccount:credential.identifier];
		if (deleteStatus != errSecSuccess) {
			GRDErrorLogg(@"Failed to delete IKEv2 password ref");
			[NSThread sleepForTimeInterval:1];
			[GRDKeychain removeKeychainItemForAccount:credential.identifier];
		}
	}
	
	NSArray *storedItems = [self credentials];
    NSMutableArray *credentialList = [NSMutableArray arrayWithArray:storedItems];
    if (credentialList.count > 0) {
		[credentialList removeObject:credential];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[GRDKeychain storeData:[NSKeyedArchiver archivedDataWithRootObject:credentialList] forAccount:kGuardianCredentialsList];
#pragma clang diagnostic pop
    }
}

@end
