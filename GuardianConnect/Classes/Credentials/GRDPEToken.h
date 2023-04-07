//
//  GRDPEToken.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 15.03.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDKeychain.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDPEToken : NSObject

/// The Password Equivalent Token itself
@property (nullable) NSString 	*token;

/// The PETs expiration date
@property (nullable) NSDate 	*expirationDate;

/// The PETs expiration date as a Unix timestamp
@property NSInteger 			expirationDateUnix;


/// Convenience init function to pickup PETs from data returned by the Connect API
/// - Parameter dict: a dictionary containing key/value pairs that can be parsed to create a GRDPEToken object
- (instancetype)initFromDictionary:(NSDictionary *)dict;

/// Convenience method to retrieve a reference to the current on device PET. Returns nil if no PET is present
+ (GRDPEToken * _Nullable)currentPEToken;

/// Indicates whether the PET expiration date is in the past
- (BOOL)isExpired;

/// Indicates whether the PET expiration date + a 7 day buffer added is in the past
- (BOOL)requiresValidation;

/// Convenience method to properly store a PET as well as the PET expiration date. Returns an error in case either the persistent write into the keychain or NSUserDefaults fails
- (NSError * _Nullable)store;

/// Convenience method to delete the persistent references of the current PET as well as the token's expiration date
- (NSError * _Nullable)destroy;

@end

NS_ASSUME_NONNULL_END
