//
//  GRDVPNHelper.h
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#import "GRDKeychain.h"
#import "GRDGatewayAPI.h"
#import "GRDServerManager.h"
#import "GRDHousekeepingAPI.h"
#import "GRDGatewayAPIResponse.h"
#import "GRDSubscriberCredential.h"

NS_ASSUME_NONNULL_BEGIN

@interface GRDVPNHelper : NSObject

typedef NS_ENUM(NSInteger, GRDVPNHelperStatusCode) {
    GRDVPNHelperSuccess,
	GRDVPNHelperFail,
    GRDVPNHelperDoesNeedMigration,
	GRDVPNHelperMigrating,
    GRDVPNHelperNetworkConnectionError, // add other network errors
    GRDVPNHelperCoudNotReachAPIError,
    GRDVPNHelperApp_VpnPrefsLoadError,
    GRDVPNHelperApp_VpnPrefsSaveError,
    GRDVPNHelperAPI_AuthenticationError,
    GRDVPNHelperAPI_ProvisioningError
};
- (void)setRetryCount:(NSInteger)retryCount;
- (NSInteger)retryCount;
+ (BOOL)activeConnectionPossible;
+ (BOOL)isPayingUser;
+ (BOOL)dayPassActive;
+ (void)setIsPayingUser:(BOOL)isPaying;
+ (void)clearVpnConfiguration;
+ (void)saveAllInOneBoxHostname:(NSString *)host;
+ (NEVPNProtocolIKEv2 *)prepareIKEv2ParametersForServer:(NSString *)server eapUsername:(NSString *)user eapPasswordRef:(NSData *)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType;

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation postCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block;
- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation completion:(void(^)(BOOL success, NSString *errorMessage))block;
- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString *_Nullable message, GRDVPNHelperStatusCode status))completion;
- (void)disconnectVPN;
- (void)createFreshUserWithSubscriberCredential:(NSString *)subscriberCredential completion:(void (^)(GRDVPNHelperStatusCode statusCode, NSString * _Nullable errString))completion;
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * _Nonnull, NSString * _Nonnull))block;
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))block;
+ (NSString *)blacklistJavascriptString;
@end

NS_ASSUME_NONNULL_END
