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
@property (readwrite, assign) BOOL onDemand; //defaults to yes
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
/// Used to determine if an active connection is possible, do we have all the necessary credentials (EAPUsername, Password, Host, etc)
+ (BOOL)activeConnectionPossible;

/// Used to determine if the current user has an active subscription
+ (BOOL)isPayingUser;

/// Used to determine if our current subscription a day pass
+ (BOOL)dayPassActive;

/// Used to set whether our current user is actively a paying customer
/// @param isPaying BOOL value that tracks whether or not the current user is a paying customer.
+ (void)setIsPayingUser:(BOOL)isPaying;

/// Used to clear all of our current VPN configuration details from user defaults and the keychain
+ (void)clearVpnConfiguration;

/// Sets our kGRDHostnameOverride variable in NSUserDefaults
+ (void)saveAllInOneBoxHostname:(NSString *)host;

/// Used to prepare NEVPNProtocolIKEv2 profile with our currrent server, eap-username, eap-password and certificate type.
/// @param server NSString value that contains the current server name ie. saopaulo-ipsec-4.sudosecuritygroup.com
/// @param user NSString value of an eap-username to authenticate with the specified server
/// @param passRef NSData representation of the eap-password to authenticate with the specified server
/// @param certType NEVPNIKEv2CertificateType the certificate type required to authenticate with the specified server
- (NEVPNProtocolIKEv2 *)prepareIKEv2ParametersForServer:(NSString *)server eapUsername:(NSString *)user eapPasswordRef:(NSData *)passRef withCertificateType:(NEVPNIKEv2CertificateType)certType;

/// Used to create a new VPN connection if an active subscription exists. This is the main function to call when no EAP credentials or subscriber credentials exist yet and you want to establish a new connection on a server that is chosen automatically for you.
/// @param mid block This is a block you can assign for when this process has approached a mid point (a server is selected, subscriber & eap credentials are generated). optional.
/// @param block block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureFirstTimeUserPostCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block;

/// Used to create a new VPN connection if an active subscription exists. This method will allow you to specify a host, a host location, a postCredential block and a completion block.
/// @param host NSString specific host you want to connect to ie saopaulo-ipsec-4.sudosecuritygroup.com
/// @param hostLocation NSString the display version of the location of the host you are connecting to ie: Sao, Paulo, Brazil
/// @param mid block This is a block you can assign for when this process has approached a mid point (a server is selected, subscriber & eap credentials are generated). optional.
/// @param block block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation postCredential:(void(^__nullable)(void))mid completion:(void(^)(BOOL success, NSString *errorMessage))block;

/// Used to create a new VPN connection if an active subscription exists. This method will allow you to specify a host, a host location and a completion block.
/// @param host NSString specific host you want to connect to ie saopaulo-ipsec-4.sudosecuritygroup.com
/// @param hostLocation NSString the display version of the location of the host you are connecting to ie: Sao, Paulo, Brazil
/// @param block block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureFirstTimeUserForHostname:(NSString *)host andHostLocation:(NSString *)hostLocation completion:(void(^)(BOOL success, NSString *errorMessage))block;

/// Used subsequently after the first time connection has been successfully made to re-connect to the current host VPN node with mainCredentials
/// @param completion block This completion block will return a message to display to the user and a status code, if the connection is successful, the message will be empty.
- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString *_Nullable message, GRDVPNHelperStatusCode status))completion;

/// Used to disconnect from the current VPN node.
- (void)disconnectVPN;

/// Safely disconnect from the current VPN node if applicable. This is best to call upon doing disconnections upon app launches. For instance, if a subscription expiration has been detected on launch, disconnect the active VPN connection. This will make certain not to disconnect the VPN if a valid state isnt detected.
- (void)forceDisconnectVPNIfNecessary;

/// Used to create standalone eap-username & eap-password on a specified host that is valid for a certain number of days. Good for exporting VPN credentials for use on other devices.
/// @param validForDays NSInteger number of days these credentials will be valid for
/// @param hostname NSString hostname to connect to ie: saopaulo-ipsec-4.sudosecuritygroup.com
/// @param block block Completion block that will contain an NSDictionary of credentials upon success
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays hostname:(NSString *)hostname completion:(void (^)(NSDictionary * _Nonnull, NSString * _Nonnull))block;

/// Used to create standalone eap-username & eap-password on an automatically chosen host that is valid for a certain number of days. Good for exporting VPN credentials for use on other devices.
/// @param validForDays NSInteger number of days these credentials will be valid for
/// @param block block Completion block that will contain an NSDictionary of credentials upon success
- (void)createStandaloneCredentialsForDays:(NSInteger)validForDays completion:(void(^)(NSDictionary *creds, NSString *errorMessage))block;

/// Doesn't appear to ever be used... obsolete code?
- (void)setRetryCount:(NSInteger)retryCount;
- (NSInteger)retryCount;

#pragma mark Shared Framework Code

+ (GRDPlanDetailType)subscriptionTypeFromDefaults;
+ (BOOL)proMode;

#if !TARGET_OS_OSX
- (void)startBackgroundTaskIfNecessary;
- (void)endBackgroundTask;
#endif

@end

NS_ASSUME_NONNULL_END
