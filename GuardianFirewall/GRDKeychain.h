//
//  GRDKeychain.h
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kKeychainStr_EapUsername @"eap-username"
#define kKeychainStr_EapPassword @"eap-password"
#define kKeychainStr_AuthToken @"auth-token"
#define kKeychainStr_APIAuthToken @"api-auth-token"
#define kKeychainStr_SubscriberCredential @"subscriber-credential"
#define kKeychainStr_PEToken @"pe-token"
#define kKeychainStr_SharedEapUsername @"shared-eap-username"
#define kKeychainStr_SharedEapPassword @"shared-eap-password"
static NSString * const kKeychainStr_DayPassAccountingToken = @"kGuardianDayPassAccountingToken";

@interface GRDKeychain : NSObject

+ (OSStatus)storePassword:(NSString *)passwordStr forAccount:(NSString *)accountKeyStr;
+ (NSString *)getPasswordStringForAccount:(NSString *)accountKeyStr;
+ (NSData *)getPasswordRefForAccount:(NSString *)accountKeyStr;
+ (OSStatus)removeKeychanItemForAccount:(NSString *)accountKeyStr;
+ (OSStatus)removeSubscriberCredentialWithRetries:(NSInteger)retryCount;
+ (void)removeAllKeychainItems;
+ (void)removeGuardianKeychainItems;

@end
