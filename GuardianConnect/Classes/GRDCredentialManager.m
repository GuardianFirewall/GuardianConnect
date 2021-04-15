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

+ (void)createCredentialForRegion:(NSString *)regionString numberOfDays:(NSInteger)numberOfDays main:(BOOL)mainCredential completion:(void(^)(GRDCredential * _Nullable cred, NSString * _Nullable error))block {
    //first get a host name
    [[GRDServerManager new] findBestHostInRegion:regionString completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
       
        if (!error){
            //now get the new credentials for said hostname
            [[GRDVPNHelper sharedInstance] createStandaloneCredentialsForDays:numberOfDays hostname:host completion:^(NSDictionary * _Nonnull creds, NSString * _Nonnull errorMessage) {
               
                if (!errorMessage){
                    //we got a hostname & credentials, got all we need!
                    GRDCredential *credential = [[GRDCredential alloc] initWithDictionary:creds hostname:host validFor:numberOfDays displayHostname:hostLocation];
                    OSStatus keychainSaving = [credential saveToKeychain];
                    if (keychainSaving == errSecSuccess){
                        if (block){
                            block(credential, nil);
                        }
                    } else {
                        if (block){
                            block(nil, @"Failed to save credential password to the keychain.");
                        }
                    }
                } else {
                    if (block){
                        block(nil,error);
                    }
                }
                
            }];
        } else {
            if (block){
                block(nil, error);
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
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:credential];
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
    NSData *newObject = [NSKeyedArchiver archivedDataWithRootObject:credential];
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

+ (NSArray <GRDCredential *>*)credentials {
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianCredentialList];
    NSMutableArray<GRDCredential*> *credentials = [NSMutableArray array];
    for (NSData *item in items) {
        GRDCredential *credential = [NSKeyedUnarchiver unarchiveObjectWithData:item];
        [credentials addObject:credential];
    }
    return credentials;
}



@end
