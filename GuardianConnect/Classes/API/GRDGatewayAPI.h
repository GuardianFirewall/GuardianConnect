//
//  GRDGatewayAPI.h
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDGatewayAPIResponse.h>
#import <GuardianConnect/GRDDebugHelper.h>

#define kSGAPI_ValidateReceipt_APIv1 @"/api/v1/verify-receipt"

#define kSGAPI_DefaultHostname @"us-west-1.sudosecuritygroup.com"
#define kSGAPI_Register @"/vpnsrv/api/register"
#define kSGAPI_SignIn @"/vpnsrv/api/signin"
#define kSGAPI_SignOut @"/vpnsrv/api/signout"
#define kSGAPI_ValidateReceipt @"/vpnsrv/api/verify-receipt"
#define kSGAPI_ServerStatus @"/vpnsrv/api/server-status"

#define kSGAPI_DeviceBase @"/vpnsrv/api/device"
#define kSGAPI_Device_Create @"/create"
#define kSGAPI_Device_SetPushToken @"/set-push-token"
#define kSGAPI_Device_GetAlerts @"/alerts"
#define kSGAPI_Device_EAP_GetCreds @"/eap-credentials"
#define kSGAPI_Device_EAP_RegenerateCreds @"/regenerate-eap-credentials"
#define kSGAPI_Device_GetPointOfAccess @"/get-point-of-access"
#define kGSAPI_Rule_AddDNS @"/rule/add-dns"
#define kGSAPI_Rule_AddIP @"/rule/add-ip"
#define kGSAPI_Rule_Delete @"/rule/delete"


typedef NS_ENUM(NSInteger, GRDNetworkHealthType) {
    GRDNetworkHealthUnknown = 0,
    GRDNetworkHealthBad,
    GRDNetworkHealthGood
};

NS_ASSUME_NONNULL_BEGIN

@interface GRDGatewayAPI : NSObject

/// can be set to true to make - (void)getEvents return dummy alerts for debgging purposes
@property BOOL dummyDataForDebugging;

/// apiAuthToken is used as a second factor of authentication by the zoe-agent API. zoe-agent expects this value to be sent in the JSON encoded body of the HTTP request for the value 'api-auth-token'
@property (strong, nonatomic, readonly) NSString *apiAuthToken;

/// deviceIdentifier and eapUsername are the same values. eapUsername is stored in the keychain for the value 'eap-username'
@property (strong, nonatomic, readonly) NSString *deviceIdentifier;

/// apiHostname holds the value of the zoe-agent instance the app is currently connected to in memory. A persistent copy of it is stored in NSUserDefaults
@property (strong, nonatomic, readonly) NSString *apiHostname;

/// timer used to regularly check on the network condition and detect network changes or outages
@property (strong, nonatomic) NSTimer * _Nullable healthCheckTimer;

/// hits an endpoint with as little data transferred as possible to verify that network requests can still be made
- (void)networkHealthCheck;

/// convenience method to start healthCheckTimer at a preset interval
- (void)startHealthCheckTimer;

/// convencience method to stop healthCheckTimer
- (void)stopHealthCheckTimer;

/// hits endpoint to probe current network health
- (void)networkProbeWithCompletion:(void (^)(BOOL status, NSError *error))completion ;

/// legacy - call the same method from GRDVPNHelper, this will be obsolete in the future
- (void)_loadCredentialsFromKeychain;

/// Load the current VPN node hostname out of NSUserDefaults
- (NSString *)baseHostname;

/// convenience method to quickly set various HTTP headers
- (NSMutableURLRequest *)_requestWithEndpoint:(NSString *)apiEndpoint andPostRequestData:(NSData *)postRequestDat;

/// endpoint: /vpnsrv/api/server-status
/// hits the endpoint for the current VPN host to check if a VPN connection can be established
- (void)getServerStatusWithCompletion:(void (^)(GRDGatewayAPIResponse *apiResponse))completion;

/// endpoint: /api/v1.2/device/<eap-username>/verify-credentials
/// Validates the existence of the current actively used EAP credentials with the VPN server. If a VPN server has been reset or the EAP credentials have been invalided and/or deleted the app needs to migrate to a new host and obtain new EAP credentials
/// A Subscriber Crednetial is required to prevent broad abuse of the endpoint, thought it is not required to provide the same Subscriber Credential which was initially used to generate the EAP credentials in the past. Any valid Subscriber Credential will be accepted
- (void)verifyEAPCredentialsUsername:(NSString *)eapUsername apiToken:(NSString *)apiToken andSubscriberCredential:(NSString *)subscriberCredential forVPNNode:(NSString *)vpnNode completion:(void(^)(BOOL success, BOOL stillValid, NSString * _Nullable errorMessage, BOOL subCredInvalid))completion;

/// endpoint: /api/v1.1/register-and-create
/// @param subscriberCredential JWT token obtained from housekeeping
/// @param validFor integer informing the API how long the EAP credentials should be valid for. A value of 30 indicated 30 days starting right now (eg. 30 days * 24 hours worth of service)
/// @param completion completion block indicating success, returning EAP Credentials as well as an API auth token or returning an error message for user consumption
- (void)registerAndCreateWithSubscriberCredential:(NSString *)subscriberCredential validForDays:(NSInteger)validFor completion:(void (^)(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.1/register-and-create
/// @param hostname The host we are creating the credential for
/// @param subscriberCredential JWT token obtained from housekeeping
/// @param validFor integer informing the API how long the EAP credentials should be valid for. A value of 30 indicated 30 days starting right now (eg. 30 days * 24 hours worth of service)
/// @param completion completion block indicating success, returning EAP Credentials as well as an API auth token or returning an error message for user consumption

- (void)registerAndCreateWithHostname:(NSString *)hostname subscriberCredential:(NSString *)subscriberCredential validForDays:(NSInteger)validFor completion:(void (^)(NSDictionary * _Nullable, BOOL, NSString * _Nullable))completion;

/// endpoint: /api/v1.2/device/<eap-username>/invalidate-credentials
/// @param eapUsername the EAP username to invalidate. Also used as the device ID
/// @param apiToken the API token for the EAP username to invalidate
/// @param completion completion block indicating a successfull API call or returning an error message
- (void)invalidateEAPCredentials:(NSString *)eapUsername andAPIToken:(NSString *)apiToken completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.1/<device_token>/set-push-token
/// @param pushToken APNS push token sent to VPN server
/// @param dataTrackers indicator whether or not to send push notifications for data trackers
/// @param locationTrackers indicator whether or not to send push notifications for location trackers
/// @param pageHijackers indicator whether or not to send push notifications for page hijackers
/// @param mailTrackers indicator whether or not to send push notifications for mail trackers
/// @param completion completion block indicating success, and an error message with information for the user
- (void)setPushToken:(NSString *)pushToken andDataTrackersEnabled:(BOOL)dataTrackers locationTrackersEnabled:(BOOL)locationTrackers pageHijackersEnabled:(BOOL)pageHijackers mailTrackersEnabled:(BOOL)mailTrackers completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.1/device/<device_token>/remove-push-token
/// @param completion completion block indicating success, and an error message with information for the user
- (void)removePushTokenWithCompletion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.1/device/<eap-username>/alerts
/// @param completion De-Serialized JSON from the server containing an array with all alerts
- (void)getEvents:(void (^)(NSDictionary *response, BOOL success, NSString *error))completion;

/// endpoint: /api/v1.2/device/<eap-username>/set-alerts-download-timestamp
/// @param timestamp Unix timestamp in seconds to indicate which alerts have already been downloaded
/// @param completion completion block indicating a successful API request or an error message with detailed information
- (void)setAlertsDownloadTimestamp:(NSInteger) timestamp completion:(void(^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.2/device/<eap-username>/alert-totals
/// @param completion completion block indicating a successful API request, if successful a dictionary with the alert totals per alert category or an error message
- (void)getAlertTotals:(void (^)(NSDictionary * _Nullable alertTotals, BOOL success, NSString * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END

