//
//  GRDCredentialManager.h
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//
// Manage EAP credentials

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDCredential.h>

NS_ASSUME_NONNULL_BEGIN
static NSString * const kGuardianCredentialList = @"kGuardianCredentialList";
@interface GRDCredentialManager : NSObject
+ (void)createCredentialForRegion:(NSString *)regionString numberOfDays:(NSInteger)numberOfDays main:(BOOL)mainCredential completion:(void(^)(GRDCredential * _Nullable cred, NSString * _Nullable error))completion;
+ (NSArray <GRDCredential *>*)credentials;
+ (NSArray <GRDCredential *>*)filteredCredentials;
+ (void)removeCredential:(GRDCredential *)credential;
+ (void)addOrUpdateCredential:(GRDCredential *)credential;
+ (GRDCredential *)credentialWithIdentifier:(NSString *)groupIdentifier;
+ (GRDCredential *)mainCredentials;
+ (void)clearMainCredentials;
@end

NS_ASSUME_NONNULL_END
