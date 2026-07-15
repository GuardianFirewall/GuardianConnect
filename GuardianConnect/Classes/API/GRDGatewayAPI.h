//
//  GRDGatewayAPI.h
//  Guardian
//
//  Copyright © 2017 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDAPIError.h>
#import <GuardianConnect/GRDCredential.h>
#import <GuardianConnect/GRDCredentialManager.h>


NS_ASSUME_NONNULL_BEGIN

@interface GRDGatewayAPI : NSObject


- (void)getServerStatusForHostname:(NSString *)hostname completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/// Used to register a new device for a given transport protocol
/// @param transportProtocol Specified what kind of VPN credentials will be returned
/// @param hostname The hostname of the VPN node
/// @param subscriberCredential The Subscriber Credential which should be used to authenticate
/// @param options Optional non-standard values which should be passed to the VPN node via the JSON body of the request
/// @param deviceFilterConfigs Dictionary containing various options to enable settings in the firewall for this credential
/// @param clientRules Customer defined traffic rules to be enforced on the firewall
/// @param multihopExitRegion Name of the region where traffic should egress after a hop from the ingress SGW server the device is connected to
/// @param completion The completion handler called once the task is compeleted
- (void)registerDeviceCredentialForTransportProtocol:(NSString *)transportProtocol hostname:(NSString *)hostname subscriberCredential:(NSString *)subscriberCredential transportOptions:(NSDictionary *)options deviceFilterConfigs:(NSDictionary *)deviceFilterConfigs clientRules:(NSArray *)clientRules multihopExitRegion:(NSString *)multihopExitRegion completion:(void (^)(NSDictionary * _Nullable credentialDetails, NSError * _Nullable error))completion;

/// Used to verify that the local credentials are still valid and can be used to establish the VPN connection again
/// @param clientId The client id assosicated with the VPN credentials
/// @param apiToken The API token to authenticate the request
/// @param hostname The hostname of the VPN node
/// @param subCred The Subscriber Credential to authenticate the request and prevent connection spoofing
/// @param completion The completion handler called once the task is completed
- (void)verifyCredentialsForClientId:(NSString *)clientId withAPIToken:(NSString *)apiToken hostname:(NSString * _Nonnull)hostname subscriberCredential:(NSString * _Nonnull)subCred completion:(void (^)(BOOL credentialsValid, NSError * _Nullable error))completion;

/// Used to invalidate a set of VPN credentials which renders them completely broken server side. They can't be used to establish a VPN connection anymore nor can the client download alerts for this client id once this API is called
/// @param clientId The client id assosicated with the VPN credentials
/// @param apiToken The API token to authenticate the request
/// @param hostname The hostname of the VPN node
/// @param subCred The Subscriber Credential to authenticate the request and prevent connection spoofing
/// @param completion The completion handler called once the task is completed
- (void)invalidateCredentialsForClientId:(NSString *)clientId apiToken:(NSString *)apiToken hostname:(NSString *)hostname subscriberCredential:(NSString *)subCred completion:(void (^)(NSError * _Nullable))completion;

/// endpoint: /api/v1.4/device/<device-id>/alerts
/// @param completion De-Serialized JSON from the server containing an array with all alerts
- (void)getEventsForClientId:(NSString *)clientId apiAuthToken:(NSString *)apiAuthToken hostname:(NSString *)hostname completion:(void(^)(NSArray *alerts, NSError *_Nullable error))completion;

/// endpoint: /api/v1.4/<device-id>/set-push-token
/// @param tokenData APNS push token sent to VPN server
/// @param completion completion block indicating success, and an error message with information for the user
- (void)setPushNotificationServiceTokenWithData:(NSDictionary *_Nonnull)tokenData hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSError * _Nullable error))completion;

/// endpoint: /api/v1.4/device/<device-id>/remove-push-token
/// @param completion completion block indicating success, and an error message with information for the user
- (void)removePushNotificationServiceTokenForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void (^)(NSError * _Nullable error))completion;


# pragma mark - Optional Firewall Configuration

- (void)getDeviceFitlerConfigsForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void(^)(NSDictionary * _Nullable configFilters, NSError * _Nullable errorMessage))completion;

- (void)setDeviceFilterConfigs:(NSDictionary *)configFilters hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiToken:(NSString *)apiToken completion:(void(^)(NSError * _Nullable errorMessage))completion;

- (void)getClientRulesForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void(^)(NSArray * _Nullable rulesRaw, NSError * _Nullable error))completion;

- (void)setClientRules:(NSArray *)rulesRaw hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void(^)(NSArray * _Nullable rulesRaw, NSError * _Nullable error))completion;

- (void)getMultihopRegionConfigsForHostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void(^)(NSDictionary * _Nullable multihopConfigs, NSError * _Nullable error))completion;

- (void)setMultihopExitRegion:(NSString *)exitRegion hostname:(NSString *)hostname deviceId:(NSString *)deviceId apiAuthToken:(NSString *)apiAuthToken completion:(void(^)(NSDictionary * _Nullable multihopConfigs, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

