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

+ (GRDCredential *)mainCredentials {
    NSArray *creds = [self credentials];
    return [[creds filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"mainCredential == true"]] firstObject];
}

+ (void)clearMainCredentials {
    GRDCredential *main = [self mainCredentials];
    if (main){
        [self removeCredential:main];
    }
}

+ (void)createCredentialForRegion:(NSString *)regionString numberOfDays:(NSInteger)numberOfDays main:(BOOL)mainCredential completion:(void(^)(GRDCredential * _Nullable cred, NSString * _Nullable error))completion {
    //first get a host name
    [[GRDServerManager new] findBestHostInRegion:regionString completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
       
        if (!error){
            //now get the new credentials for said hostname
            [[GRDVPNHelper sharedInstance] createStandaloneCredentialsForDays:numberOfDays hostname:host completion:^(NSDictionary * _Nonnull creds, NSString * _Nonnull errorMessage) {
               
                if (!errorMessage){
                    //we got a hostname & credentials, got all we need!
                    NSMutableDictionary *credCopy = [creds mutableCopy];
                    credCopy[kGRDHostnameOverride] = host;
                    credCopy[kGRDVPNHostLocation] = hostLocation;
                    GRDCredential *credential = [[GRDCredential alloc] initWithFullDictionary:credCopy validFor:numberOfDays isMain:mainCredential];
                    OSStatus keychainSaving = [credential saveToKeychain];
                    if (keychainSaving == errSecSuccess){
                        if (completion){
                            completion(credential, nil);
                        }
                    } else {
                        if (completion){
                            completion(nil, @"Failed to save credential password to the keychain.");
                        }
                    }
                } else {
                    if (completion){
                        completion(nil,error);
                    }
                }
                
            }];
        } else {
            if (completion){
                completion(nil, error);
            }
        }
    }];
}

+ (GRDCredential *)credentialWithIdentifier:(NSString *)identifier {
    NSArray <GRDCredential*> *credentials = [self credentials];
    return [[credentials filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]] lastObject];
}

+ (void)removeCredential:(GRDCredential *)credential {
    if (!credential) { return; }
    [credential removeFromKeychain];
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianCredentialList];
    NSMutableArray<NSData *> *credentialList = [NSMutableArray arrayWithArray:storedItems];
    if (credentialList.count) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:credential];
#pragma clang diagnostic pop
        [credentialList removeObject:itemData];
        [[NSUserDefaults standardUserDefaults] setValue:credentialList forKey:kGuardianCredentialList];
    }
}

+ (void)addOrUpdateCredential:(GRDCredential *)credential {
    if (!credential) { return; }
    NSMutableArray<NSData *> *credentialList = [[[NSUserDefaults standardUserDefaults] objectForKey:kGuardianCredentialList] mutableCopy];
    if (!credentialList.count) {
        credentialList = [NSMutableArray array];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSData *newObject = [NSKeyedArchiver archivedDataWithRootObject:credential];
#pragma clang diagnostic pop
    GRDCredential *foundCred = [self credentialWithIdentifier:credential.identifier];
    if (foundCred){
        NSArray *creds = [self credentials]; //this is REALLY inefficient, may have to stop dodging making this a singleton
        NSInteger index = [creds indexOfObject:foundCred];
        if (index != NSNotFound){
            [credentialList replaceObjectAtIndex:index withObject:newObject];
        } else {
            //should NOT happen...
            [credentialList insertObject:newObject atIndex:0];
        }
    } else {
        [credentialList insertObject:newObject atIndex:0];
    }
    
    [[NSUserDefaults standardUserDefaults] setValue:credentialList forKey:kGuardianCredentialList];
}

+ (NSArray <GRDCredential *>*)filteredCredentials { //credentials minus the main credentials, for use in EAP view
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianCredentialList];
    NSMutableArray<GRDCredential*> *credentials = [NSMutableArray array];
    for (NSData *item in items) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        GRDCredential *credential = [NSKeyedUnarchiver unarchiveObjectWithData:item];
#pragma clang diagnostic pop
        if (![credential mainCredential]){
            [credentials addObject:credential];
        }
    }
    return credentials;
}

+ (NSArray <GRDCredential *>*)credentials {
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianCredentialList];
    NSMutableArray<GRDCredential*> *credentials = [NSMutableArray array];
    for (NSData *item in items) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        GRDCredential *credential = [NSKeyedUnarchiver unarchiveObjectWithData:item];
#pragma clang diagnostic pop
        [credentials addObject:credential];
    }
    return credentials;
}



@end
