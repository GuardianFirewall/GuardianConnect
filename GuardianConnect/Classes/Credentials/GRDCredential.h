//
//  GRDCredential.h
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDCredential : NSObject

@property NSString *name;
@property NSString *identifier;
@property NSString *username;
@property NSString *password;
@property NSString *hostname;
@property NSDate *expirationDate;
@property NSString *hostnameDisplayValue;
@property NSString *apiAuthToken;
@property BOOL mainCredential; //experimental
@property NSData *passwordRef;

- (NSString *)prettyHost;
- (NSString *)defaultFileName;
- (id)initWithFullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (id)initWithDictionary:(NSDictionary *)credDict hostname:(NSString *)hostname expiration:(NSDate *)expirationDate;
- (void)updateWithItem:(GRDCredential *)cred;
- (OSStatus)saveToKeychain;
- (BOOL)loadFromKeychain;
- (NSString *)truncatedHost;
- (OSStatus)removeFromKeychain;
- (NSString *)authTokenIdentifier;
- (BOOL)expired;
- (NSInteger)daysLeft; //days until it does expire
- (BOOL)canRevoke; //legacy credentials are missing the API auth token so they cant be revoked.
- (void)revokeCredentialWithCompletion:(void(^)(BOOL success, NSString *errorMessage))block;
@end

NS_ASSUME_NONNULL_END
