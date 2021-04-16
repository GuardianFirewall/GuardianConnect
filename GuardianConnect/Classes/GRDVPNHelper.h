//
//  GRDVPNHelper.h
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDGatewayAPI.h>
#import <GuardianConnect/GRDServerManager.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>
#import <GuardianConnect/GRDGatewayAPIResponse.h>
#import <GuardianConnect/GRDSubscriberCredential.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import <GuardianConnect/GRDCredentialManager.h>
NS_ASSUME_NONNULL_BEGIN

@interface GRDVPNHelper : NSObject

@property (nullable) NEProxySettings *proxySettings;
@property (nullable) GRDCredential *mainCredential;
#if !TARGET_OS_OSX
@property UIBackgroundTaskIdentifier bgTask;
#endif

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
+ (instancetype)sharedInstance;

#if !TARGET_OS_OSX
- (void)startBackgroundTaskIfNecessary;
- (void)endBackgroundTask;
#endif

- (void)setRetryCount:(NSInteger)retryCount;
- (NSInteger)retryCount;
+ (BOOL)activeConnectionPossible;
+ (BOOL)isPayingUser;
+ (BOOL)dayPassActive;
+ (void)setIsPayingUser:(BOOL)isPaying;
+ (void)clearVpnConfiguration;
+ (void)saveAllInOneBoxHostname:(NSString *)host;
- (NEVPNProtocolIKEv2 *)prepareIKEv2ParametersForServer:(NSString *)server eapUsername:(NSString *)user eapPasswordRef:(NSData *)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType;

- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block;

- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation postCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block;
- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation completion:(void(^)(BOOL success, NSString *errorMessage))block;
- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString *_Nullable message, GRDVPNHelperStatusCode status))completion;
- (void)disconnectVPN;
- (void)forceDisconnectVPNIfNecessary;
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * _Nonnull, NSString * _Nonnull))block;
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))block;

#pragma mark Shared Framework Code

+ (GRDPlanDetailType)subscriptionTypeFromDefaults;
+ (BOOL)proMode; //not used yet, moving here to help framework transition.

@end

NS_ASSUME_NONNULL_END
