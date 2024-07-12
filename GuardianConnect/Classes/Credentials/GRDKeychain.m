//
//  GRDKeychain.m
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDVPNhelper.h>
#import <GuardianConnect/GRDCredentialManager.h>

@interface GRDKeychain ()

@end

@implementation GRDKeychain

+ (OSStatus)storePassword:(NSString *)passwordStr forAccount:(NSString *)accountKeyStr {
    if (passwordStr == nil) {
		GRDErrorLogg(@"No EAP password provided!");
        return errSecParam;
    }
	
    CFTypeRef result = NULL;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSData *valueData = [passwordStr dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableDictionary *mSecItem = [NSMutableDictionary new];
	[mSecItem setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
	[mSecItem setObject:bundleId forKey:(__bridge id)kSecAttrService];
	[mSecItem setObject:(__bridge id)kCFBooleanFalse forKey:(__bridge id)kSecAttrSynchronizable];
	[mSecItem setObject:accountKeyStr forKey:(__bridge id)kSecAttrAccount];
	[mSecItem setObject:valueData forKey:(__bridge id)kSecValueData];
	
	if ([accountKeyStr isEqualToString:kGuardianCredentialsList] == YES) {
		[mSecItem setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
	
	} else {
		[mSecItem setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
	}
	
	if ([accountKeyStr isEqualToString:kKeychainStr_WireGuardConfig]) {
		NSString *appGroupId = [[GRDVPNHelper sharedInstance] appGroupIdentifier];
		if (appGroupId == nil) {
			appGroupId = @"";
		}
		[mSecItem setObject:appGroupId forKey:(__bridge id)kSecAttrAccessGroup];
	}
	
	NSDictionary *secItem = [NSDictionary dictionaryWithDictionary:mSecItem];
	
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)secItem, &result);
    if (status != errSecSuccess) {
        if (status == errSecDuplicateItem) {
            [self removeKeychainItemForAccount:accountKeyStr];
            return [self storePassword:passwordStr forAccount:accountKeyStr];
        }
        GRDErrorLogg(@"Error storing password item '%@' OSStatus error: %ld", accountKeyStr, (long)status);
    }
	
    return status;
}

+ (OSStatus)storeData:(NSData *)data forAccount:(NSString *)accountKeyString {
	if (data == nil) {
		return errSecParam; //technically it IS a parameter issue, so this makes sense.
	}
	
	CFTypeRef result = NULL;
	NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
	
	NSMutableDictionary *mSecItem = [NSMutableDictionary new];
	[mSecItem setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
	[mSecItem setObject:bundleId forKey:(__bridge id)kSecAttrService];
	[mSecItem setObject:(__bridge id)kCFBooleanFalse forKey:(__bridge id)kSecAttrSynchronizable];
	[mSecItem setObject:accountKeyString forKey:(__bridge id)kSecAttrAccount];
	[mSecItem setObject:data forKey:(__bridge id)kSecValueData];
	
	if ([accountKeyString isEqualToString:kGuardianCredentialsList] == YES) {
		[mSecItem setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
	
	} else {
		[mSecItem setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
	}
	NSDictionary *secItem = [NSDictionary dictionaryWithDictionary:mSecItem];
	
	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)secItem, &result);
	if (status != errSecSuccess) {
		if (status == errSecDuplicateItem) {
			[self removeKeychainItemForAccount:accountKeyString];
			return [self storeData:data forAccount:accountKeyString];
		}
		GRDErrorLogg(@"Error storing data item '%@' OSStatus error: %ld", accountKeyString, (long)status);
	}
	
	return status;
}

+ (NSString *)getPasswordStringForAccount:(NSString *)accountKeyStr {
    CFTypeRef copyResult = NULL;
    NSString *passStr = nil;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSDictionary *query = @{
                            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService : bundleId,
                            (__bridge id)kSecAttrAccount : accountKeyStr,
                            (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
                            (__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
                            };
    OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&copyResult);
    if (results == errSecSuccess) {
        passStr = [[NSString alloc] initWithBytes:[(__bridge_transfer NSData *)copyResult bytes]
                                           length:[(__bridge NSData *)copyResult length] encoding:NSUTF8StringEncoding];
    } else if (results != errSecItemNotFound) {
		GRDErrorLogg(@"Error obtaining keychain data for item '%@': %ld", accountKeyStr, (long)results);
        if (@available(iOS 11.3, *)) {
            NSString *errMessage = CFBridgingRelease(SecCopyErrorMessageString(results, nil));
			GRDErrorLogg(@"Error message: %@", errMessage);
        }
    }
    
    return passStr;
}

+ (NSData *)getPasswordRefForAccount:(NSString *)accountKeyStr {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    CFTypeRef copyResult = NULL;
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : bundleId,
        (__bridge id)kSecAttrAccount : accountKeyStr,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
        (__bridge id)kSecReturnPersistentRef : (__bridge id)kCFBooleanTrue,
    };
    OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&copyResult);
    if (results != errSecSuccess && results != errSecItemNotFound) {
		GRDErrorLogg(@"Failed to  obtain keychain data for item '%@': %ld", accountKeyStr, (long)results);
    }
    
    return (__bridge NSData *)copyResult;
}

+ (NSData *)getDataForAccount:(NSString *)accountKeyString {
	CFTypeRef copyResult = NULL;
	NSData *returnData = nil;
	NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
	NSDictionary *query = @{
							(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
							(__bridge id)kSecAttrService : bundleId,
							(__bridge id)kSecAttrAccount : accountKeyString,
							(__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne,
							(__bridge id)kSecReturnData : (__bridge id)kCFBooleanTrue,
							};
	OSStatus results = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&copyResult);
	if (results == errSecSuccess) {
		returnData = [[NSData alloc] initWithBytes:[(__bridge_transfer NSData *)copyResult bytes] length:[(__bridge NSData *)copyResult length]];
		
	} else if (results != errSecItemNotFound) {
		GRDErrorLogg(@"Error obtaining keychain data for item '%@': %ld", accountKeyString, (long)results);
		if (@available(iOS 11.3, *)) {
			NSString *errMessage = CFBridgingRelease(SecCopyErrorMessageString(results, nil));
			GRDErrorLogg(@"Error message: %@", errMessage);
		}
	}
	
	return returnData;
}

+ (void)removeGuardianKeychainItems {
    NSArray *guardianKeys = @[kKeychainStr_EapUsername,
                              kKeychainStr_EapPassword,
                              kKeychainStr_APIAuthToken,
							  kKeychainStr_WireGuardConfig];
    [guardianKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeKeychainItemForAccount:obj];
    }];
	[GRDCredentialManager clearMainCredentials];
}

+ (OSStatus)removeSubscriberCredentialWithRetries:(NSInteger)retryCount {
    OSStatus status = errSecSuccess;
    for (NSInteger i = 0; i < retryCount; i++) {
        status = [self removeKeychainItemForAccount:kKeychainStr_SubscriberCredential];
        NSString *sanityCheck = [self getPasswordStringForAccount:kKeychainStr_SubscriberCredential];
        if (status == errSecSuccess || sanityCheck == nil || status == errSecItemNotFound) {
            GRDDebugLog(@"Subscriber Credential keychain removal success on try %li", (long)i);
            return status;
            
        } else { //either not errSecSuccess // errSecItemNotFound or the item still exists
            if (sanityCheck != nil) {
				GRDErrorLogg(@"Subscriber Credential keychain removal error occured, credential still exists!");
                
            } else {
				GRDErrorLogg(@"Subscriber Credential keychain removal error occured: %d", (int)status);
            }
        }
    }
    return status;
}

+ (OSStatus)removeKeychainItemForAccount:(NSString *)accountKeyStr {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSDictionary *query = @{
                            (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService : bundleId,
                            (__bridge id)kSecAttrAccount : accountKeyStr,
                            (__bridge id)kSecReturnPersistentRef : (__bridge id)kCFBooleanTrue,
                            };
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)query);
    if (result != errSecSuccess && result != errSecItemNotFound) {
        if (@available(iOS 11.3, *)) {
            NSString *errMessage = CFBridgingRelease(SecCopyErrorMessageString(result, nil));
			GRDErrorLogg(@"Error message: %@", errMessage);
        }
        GRDErrorLogg(@"Failed to delete password entry '%@' with status: %ld", accountKeyStr, (long)result);
    }
    
    return result;
}

+ (void)removeAllKeychainItems {
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];
    for (id secItemClass in secItemClasses) {
        NSDictionary *itemClass = @{(__bridge id)kSecClass:secItemClass};
        GRDLogg(@"Removed keychain class: %@", itemClass);
        SecItemDelete((__bridge CFDictionaryRef)itemClass);
    }
}

@end
