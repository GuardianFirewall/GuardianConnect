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
	
	[GRDKeychain storeData:[NSKeyedArchiver archivedDataWithRootObject:credentialList] forAccount:kGuardianCredentialsList];
#pragma clang diagnostic pop
}

+ (void)removeCredential:(GRDCredential *)credential {
    if (!credential) { return; }
    [credential removeFromKeychain];
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

+ (BOOL)migrateKeychainItemsToGRDCredential {
    NSString *eapUsername = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapUsername];
    NSString *eapPassword = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapPassword];
    NSString *apiAuthToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_APIAuthToken];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *hostname = [defaults stringForKey:kGRDHostnameOverride];
    NSString *hostnameLocation = [defaults stringForKey:kGRDVPNHostLocation];
    
    if (eapUsername != nil || eapPassword == nil || apiAuthToken == nil || hostname == nil || hostnameLocation == nil) {
        GRDWarningLogg(@"nil value detected. Nothing to migrate");
        GRDWarningLogg(@"\neap username: %@\neap password: %@\napi auth token: %@\nhostname: %@\nhostname location: %@", eapUsername, eapPassword, apiAuthToken, hostname, hostnameLocation);
        return NO;
    }
    
    GRDCredential *newMain = [[GRDCredential alloc] initWithFullDictionary:@{kKeychainStr_EapUsername: eapUsername, kKeychainStr_EapPassword: eapPassword, kKeychainStr_APIAuthToken: apiAuthToken, kGRDHostnameOverride: hostname, kGRDVPNHostLocation: hostnameLocation} validFor:30 isMain:YES];
    [self addOrUpdateCredential:newMain];
    
    [[GRDVPNHelper sharedInstance] setMainCredential:newMain];
    return YES;
}

+ (void)createCredentialForRegion:(NSString *)regionString numberOfDays:(NSInteger)numberOfDays main:(BOOL)mainCredential completion:(void(^)(GRDCredential * _Nullable cred, NSString * _Nullable error))completion {
	//first get a host name
	[[GRDServerManager new] findBestHostInRegion:regionString completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
		if (!error) {
			//now get the new credentials for said hostname
			[[GRDVPNHelper sharedInstance] createStandaloneCredentialsForDays:numberOfDays hostname:host completion:^(NSDictionary * _Nonnull creds, NSString * _Nonnull errorMessage) {
				if (!errorMessage) {
					//we got a hostname & credentials, got all we need!
					NSMutableDictionary *credCopy = [creds mutableCopy];
					credCopy[kGRDHostnameOverride] = host;
					credCopy[kGRDVPNHostLocation] = hostLocation;
					GRDCredential *credential = [[GRDCredential alloc] initWithFullDictionary:credCopy validFor:numberOfDays isMain:mainCredential];
					OSStatus keychainSaving = [credential saveToKeychain];
					if (keychainSaving == errSecSuccess) {
						if (completion) {
							completion(credential, nil);
						}
						
					} else {
						if (completion) {
							completion(nil, @"Failed to save credential password to the keychain.");
						}
					}
					
				} else {
					if (completion) {
						completion(nil,error);
					}
				}
			}];
			
		} else {
			if (completion) {
				completion(nil, error);
			}
		}
	}];
}

+ (void)createCredentialForRegion:(NSString *)region withTransportProtocol:(TransportProtocol)protocol numberOfDays:(NSInteger)numberOfDays main:(BOOL)mainCredential completion:(void (^)(GRDCredential * _Nullable, NSString * _Nullable))completion {
	//first get a host name
	[[GRDServerManager new] findBestHostInRegion:region completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
		if (!error) {
			//now get the new credentials for said hostname
			[[GRDVPNHelper sharedInstance] createStandaloneCredentialsForTransportProtocol:protocol validForDays:numberOfDays hostname:host completion:^(NSDictionary * _Nonnull credentials, NSString * _Nonnull errorMessage) {
				if (!errorMessage) {
					//we got a hostname & credentials, got all we need!
					NSMutableDictionary *credCopy = [credentials mutableCopy];
					credCopy[kGRDHostnameOverride] = host;
					credCopy[kGRDVPNHostLocation] = hostLocation;
					GRDCredential *credential = [[GRDCredential alloc] initWithTransportProtocol:protocol fullDictionary:credCopy validFor:numberOfDays isMain:mainCredential];
					if (completion) {
						completion(credential, nil);
					}
					
				} else {
					if (completion) {
						completion(nil,error);
					}
				}
			}];
			
		} else {
			if (completion) {
				completion(nil, error);
			}
		}
	}];
}


@end
