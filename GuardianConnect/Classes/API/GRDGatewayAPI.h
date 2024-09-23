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
#import <GuardianConnect/GRDCredential.h>
#import <GuardianConnect/GRDAPIError.h>


NS_ASSUME_NONNULL_BEGIN

@interface GRDGatewayAPI : NSObject

/// can be set to true to make - (void)getEvents return dummy alerts for debgging purposes
@property BOOL dummyDataForDebugging; //obsolete, moved to GRDVPNHelper

/// apiAuthToken is used as a second factor of authentication by the zoe-agent API. zoe-agent expects this value to be sent in the JSON encoded body of the HTTP request for the value 'api-auth-token'
@property (strong, nonatomic, readonly) NSString *apiAuthToken;

/// deviceIdentifier and eapUsername are the same values. eapUsername is stored in the keychain for the value 'eap-username'
@property (strong, nonatomic, readonly) NSString *deviceIdentifier;

/// apiHostname holds the value of the zoe-agent instance the app is currently connected to in memory. A persistent copy of it is stored in NSUserDefaults
@property (strong, nonatomic, readonly) NSString *apiHostname;

/// Load the current VPN node hostname out of NSUserDefaults
- (NSString *)baseHostname;


/// endpoint: /vpnsrv/api/server-status
/// hits the endpoint for the current VPN host to check if a VPN connection can be established
- (void)getServerStatusWithCompletion:(void (^ _Nullable)(NSString * _Nullable errorMessage))completion;

/// Used to register a new device for a given transport protocol
/// @param transportProtocol Specified what kind of VPN credentials will be returned
/// @param hostname The hostname of the VPN node
/// @param subscriberCredential The Subscriber Credential which should be used to authenticate
/// @param validFor The amount of days the VPN credentials should be valid for
/// @param options Optional non-standard values which should be passed to the VPN node via the JSON body of the request
/// @param completion The completion handler called once the task is compeleted
- (void)registerDeviceForTransportProtocol:(NSString * _Nonnull)transportProtocol hostname:(NSString * _Nonnull)hostname subscriberCredential:(NSString * _Nonnull)subscriberCredential validForDays:(NSInteger)validFor transportOptions:(NSDictionary * _Nullable)options completion:(void (^)(NSDictionary * _Nullable credentialDetails, BOOL success, NSString * _Nullable errorMessage))completion;

/// Used to verify that the local credentials are still valid and can be used to establish the VPN connection again
/// @param clientId The client id assosicated with the VPN credentials
/// @param apiToken The API token to authenticate the request
/// @param hostname The hostname of the VPN node
/// @param subCred The Subscriber Credential to authenticate the request and prevent connection spoofing
/// @param completion The completion handler called once the task is completed
- (void)verifyCredentialsForClientId:(NSString *)clientId withAPIToken:(NSString *)apiToken hostname:(NSString * _Nonnull)hostname subscriberCredential:(NSString * _Nonnull)subCred completion:(void (^)(BOOL success, BOOL credentialsValid, NSString * _Nullable errorMessage))completion;

/// Used to invalidate a set of VPN credentials which renders them completely broken server side. They can't be used to establish a VPN connection anymore nor can the client download alerts for this client id once this API is called
/// @param clientId The client id assosicated with the VPN credentials
/// @param apiToken The API token to authenticate the request
/// @param hostname The hostname of the VPN node
/// @param subCred The Subscriber Credential to authenticate the request and prevent connection spoofing
/// @param completion The completion handler called once the task is completed
- (void)invalidateCredentialsForClientId:(NSString *)clientId apiToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(BOOL, NSString * _Nullable))completion;

/// endpoint: /api/v1.1/device/<eap-username>/alerts
/// @param completion De-Serialized JSON from the server containing an array with all alerts
- (void)getEvents:(void (^)(NSDictionary *response, BOOL success, NSString *_Nullable error))completion;

/// endpoint: /api/v1.2/device/<eap-username>/set-alerts-download-timestamp
/// @param completion completion block indicating a successful API request or an error message with detailed information
- (void)setAlertsDownloadTimestampWithCompletion:(void(^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.2/device/<eap-username>/alert-totals
/// @param completion completion block indicating a successful API request, if successful a dictionary with the alert totals per alert category or an error message
- (void)getAlertTotals:(void (^)(NSDictionary * _Nullable alertTotals, BOOL success, NSString * _Nullable errorMessage))completion;


/// endpoint: /api/v1.1/<device_token>/set-push-token
/// @param pushToken APNS push token sent to VPN server
/// @param dataTrackers indicator whether or not to send push notifications for data trackers
/// @param locationTrackers indicator whether or not to send push notifications for location trackers
/// @param pageHijackers indicator whether or not to send push notifications for page hijackers
/// @param mailTrackers indicator whether or not to send push notifications for mail trackers
/// @param completion completion block indicating success, and an error message with information for the user
- (void)setPushToken:(NSString *_Nonnull)pushToken andDataTrackersEnabled:(BOOL)dataTrackers locationTrackersEnabled:(BOOL)locationTrackers pageHijackersEnabled:(BOOL)pageHijackers mailTrackersEnabled:(BOOL)mailTrackers completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1.1/device/<device_token>/remove-push-token
/// @param completion completion block indicating success, and an error message with information for the user
- (void)removePushTokenWithCompletion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;


# pragma mark - Device Filter Configs

/// Upon success will return a NSDictionary containing four booleans
- (void)getDeviceFitlerConfigsForDeviceId:(NSString * _Nonnull)deviceId apiToken:(NSString * _Nonnull)apiToken completion:(void(^)(NSDictionary * _Nullable configFilters, NSError * _Nullable errorMessage))completion;

/// Will run through all keys and values in configFilters and send them to the VPN node
- (void)setDeviceFilterConfigsForDeviceId:(NSString * _Nonnull)deviceId apiToken:(NSString * _Nonnull)apiToken deviceConfigFilters:(NSDictionary * _Nonnull)configFilters completion:(void(^)(NSError * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END

