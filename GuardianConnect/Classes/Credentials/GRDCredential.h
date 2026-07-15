//
//  GRDCredential.h
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDAlert.h>
#import <GuardianConnect/GRDTransportProtocol.h>

//
// Note from CJ 2024-04-20
// GRDRegion is being imported via the @class operator here to prevent
// a circular import and the compiler being very sad
@class GRDRegion;
@class GRDSGWServer;

NS_ASSUME_NONNULL_BEGIN

@interface GRDCredential : NSObject <NSSecureCoding>

// Properties used by all credentials
@property NSString 	        *name;
@property NSString 	        *identifier;
@property BOOL              mainCredential;
@property TransportProtocol transportProtocol;
@property NSDate 	        *expirationDate;
@property GRDSGWServer 		*server;
@property NSString 	        *hostname;
@property NSString 	        *hostnameDisplayValue;
@property GRDRegion 		* _Nullable region;
@property NSString          *clientId;
@property NSString          *apiAuthToken;

// IKEv2 related properties
@property NSString 	* _Nullable username;
@property NSString 	* _Nullable password;
@property NSData 	* _Nullable passwordRef;

// WireGuard related properties
@property NSString * _Nullable devicePublicKey;
@property NSString * _Nullable devicePrivateKey;
@property NSString * _Nullable serverPublicKey;
@property NSString * _Nullable IPv4Address;
@property NSString * _Nullable IPv6Address;


- (instancetype)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict server:(GRDSGWServer *)server validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds;
- (void)updateWithItem:(GRDCredential *)cred;
- (NSString *)prettyHost;
- (NSString *)truncatedHost;
- (NSString *)defaultFileName;
- (BOOL)expired;
- (NSInteger)daysLeft; //days until it does expire

/// Convenience helper in order to quickly determine whether the SGW credentials contains
/// the required information in order to send API requests
- (BOOL)canSendSGWAPIRequests;

/// Returns an array of GRDAlert objects. If no connections have been blocked yet
/// on the SGW host, an empty array will be returned
/// - Parameter completion: completion block returning either an error or an array of alerts
- (void)downloadAlerts:(void(^)(NSArray * _Nullable alerts, NSError * _Nullable error))completion;

/// Validates that all required parameters are present for a functional SGW credential
/// and explicitly confirms whether the SGW credential is still valid
///
/// credentialValid being returned in the completion block confirms that the SDK was able
/// to successfully connect to the SGW host and that the SGW credential is still valid. Only
/// if everything has succeeded will credentialValid be returned a YES/true
/// - Parameter completion: completion block returning a boolean to confirm that the SGW credential is still valid or an error
- (void)verifyWithCompletion:(void(^)(BOOL credentialValid, NSError * _Nullable error))completion;

/// Permanently invalidates SGW credential, preventing any futurue use of it
/// - Parameter completion: completion block containing an error in case something has gone wrong, otherwise nil
- (void)revokeCredentialWithCompletion:(void(^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
