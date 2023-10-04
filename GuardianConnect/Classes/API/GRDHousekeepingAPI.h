//
//  GRDHousekeepingAPI.h
//  Guardian
//
//  Created by Constantin Jacob on 18.11.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDReceiptLineItem.h>
#import <GuardianConnect/GRDAPIError.h>

//#define kConnectAPIHostname @"connect-api.guardianapp.com"

NS_ASSUME_NONNULL_BEGIN

@interface GRDHousekeepingAPI : NSObject

/// Validation Method used to obtain a signed JWT from housekeeping
typedef NS_ENUM(NSInteger, GRDHousekeepingValidationMethod) {
    ValidationMethodInvalid = -1,
    ValidationMethodAppStoreReceipt,
    ValidationMethodPEToken,
	ValidationMethodCustom
};

/// The GuardianConnect API hostname to use for the majority of API calls
/// WARNING: Some API endpoints are always going to use the public Connect
/// API hostname https://connect-api.guardianapp.com
/// If no custom hostname is provided, the default public Connect API hostname is going to be used
@property NSString *connectAPIHostname;

/// ValidationMethod to use for the request to housekeeping
/// Currently not used for anything since the validation method is passed to the method directly as a parameter
@property GRDHousekeepingValidationMethod validationMethod;

/// Digital App Store Receipt used to obtain a signed JWT from housekeeping
/// Currently not used since the App Store Receipt is encoded and sent to housekeeping directly from the method itself. Meant as debugging/manual override option in the future
@property NSString *appStoreReceipt;

/// PET or PE Token == Password Equivalent Token
/// Currently only used by Guardian for subscriptions & purchases conducted via the web
@property NSString *peToken;

/// GuardianConnect app public key used to authenticate API requests
@property (nonatomic, strong) NSString *_Nullable publishableKey;

/// Helper function to quickly determine the correct Connect API env the request should be send to
/// @param apiEndpoint the Connect REST API endpoint that the request should be sent to
- (NSMutableURLRequest *)connectAPIRequestFor:(NSString *)apiEndpoint;

/// endpoint: /api/v1/users/info-for-pe-token
/// @param token password equivalent token for which to request information for
/// @param completion completion block returning NSDictionary with information for the requested token, an error message and a bool indicating success of the request
- (void)requestPETokenInformationForToken:(NSString *)token completion:(void (^)(NSDictionary * _Nullable peTokenInfo, NSError * _Nullable errorMessage))completion;

/// endpoint: /api/v1.2/verify-receipt
/// Used to verify the current subscription status of a user if they subscribed through an in-app purchase. Returns an array containing only valid subscriptions / purchases
/// @param encodedReceipt Base64 encoded AppStore receipt. If the value is NULL, [NSBundle mainBundle] appStoreReceiptURL] will be used to grab the system App Store receipt
/// @param bundleId The apps bundle id used to identify the shared secret server side to decrypt the receipt data
/// @param completion completion block returning array only containing valid subscriptions / purchases, success indicator and a error message containing actionable information for the user if the request failed
- (void)verifyReceipt:(NSString * _Nullable)encodedReceipt bundleId:(NSString * _Nonnull)bundleId completion:(void (^)(NSArray <GRDReceiptLineItem *>* _Nullable validLineItems, BOOL success, NSString * _Nullable errorMessage))completion;

- (void)verifyReceiptData:(NSString * _Nullable)receiptData bundleId:(NSString * _Nonnull)bundleId completion:(void (^_Nullable)(NSDictionary * _Nullable receipt, NSError * _Nullable error))completion;

/// endpoint: /api/v1.2/subscriber-credential/create
/// Used to obtain a signed JWT from housekeeping for later authentication with zoe-agent
/// @param validationMethod set to determine how to authenticate with housekeeping
/// @param dict NSDictionary only used when the 'validationMethod' is set to 'ValidationMethodCustom'
/// @param completion completion block returning a signed JWT, indicating request success and a user actionable error message if the request failed
- (void)createSubscriberCredentialForBundleId:(NSString *)bundleId withValidationMethod:(GRDHousekeepingValidationMethod)validationMethod customKeys:(NSMutableDictionary * _Nullable)dict completion:(void (^)(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1/servers/timezones-for-regions
/// Used to obtain all known timezones
/// @param completion completion block returning an array with all timezones, indicating request success, and the response status code
- (void)requestTimeZonesForRegionsWithCompletion:(void (^)(NSArray  * _Nullable timeZones, BOOL success, NSUInteger responseStatusCode))completion;

/// endpoint: /api/v1/servers/hostnames-for-region
/// @param region the selected region for which hostnames should be returned
/// @param completion completion block returning an array of servers and indicating request success
- (void)requestServersForRegion:(NSString *)region paidServers:(BOOL)paidServers featureEnvironment:(GRDServerFeatureEnvironment)featureEnvironment betaCapableServers:(BOOL)betaCapable completion:(void (^)(NSArray *servers, BOOL success))completion;

/// endpint: /api/v1/servers/all-hostnames
/// @param completion completion block returning an array of all hostnames and indicating request success
- (void)requestAllHostnamesWithCompletion:(void (^)(NSArray * _Nullable allServers, BOOL success))completion;

/// endpoint: /api/v1/servers/all-server-regions
/// Used to retrieve all available Server Regions from housekeeping to allow users to override the selected Server Region
/// @param completion completion block returning an array contain a dictionary for each server region and a BOOL indicating a successful API call
- (void)requestAllServerRegions:(void (^)(NSArray <NSDictionary *> * _Nullable items, BOOL success, NSError * _Nullable errorMessage))completion;


# pragma mark - Connect Subscriber

- (void)newConnectSubscriberWith:(NSString * _Nonnull)identifier secret:(NSString * _Nonnull)secret acceptedTOS:(BOOL)acceptedTOS email:(NSString * _Nullable)email andCompletion:(void (^)(NSDictionary * _Nullable subscriberDetails, NSError * _Nullable errorMessage))completion;

- (void)updateConnectSubscriberWith:(NSString * _Nonnull)email identifier:(NSString * _Nonnull)identifier secret:(NSString * _Nonnull)secret andCompletion:(void (^)(NSDictionary * _Nullable subscriberDetails, NSError * _Nullable errorMessage))completion;

- (void)validateConnectSubscriberWith:(NSString * _Nonnull)identifier secret:(NSString * _Nonnull)secret pet:(NSString * _Nonnull)pet andCompletion:(void (^)(NSDictionary * _Nullable details, NSError * _Nullable errorMessage))completion;

- (void)logoutConnectSubscriberWithPEToken:(NSString *)pet andCompletion:(void (^)(NSError * _Nullable error))completion;


# pragma mark - Connect Subscriber Devices

- (void)addConnectDeviceWith:(NSString * _Nonnull)peToken nickname:(NSString * _Nonnull)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(NSDictionary * _Nullable deviceDetails, NSError * _Nullable errorMessage))completion;

- (void)updateConnectDevice:(NSString * _Nonnull)deviceUUID withPEToken:(NSString * _Nonnull)peToken nickname:(NSString * _Nonnull)nickname andCompletion:(void (^)(NSDictionary * _Nullable deviceDetails, NSError * _Nullable errorMessage))completion;

- (void)listConnectDevicesForPEToken:(NSString * _Nullable)peToken orIdentifier:(NSString * _Nullable)identifier andSecret:(NSString * _Nullable)secret withCompletion:(void (^)(NSArray * _Nullable devices, NSError * _Nullable errorMessage))completion;

- (void)deleteConnectDevice:(NSString * _Nonnull)deviceUUID withPEToken:(NSString * _Nullable)peToken orIdentifier:(NSString * _Nullable)identifier andSecret:(NSString * _Nullable)secret andCompletion:(void (^)(NSError * _Nullable errorMessage))completion;

- (void)validateConnectDevicePEToken:(NSString * _Nonnull)peToken andCompletion:(void (^)(NSDictionary * _Nullable deviceDetails, NSError * _Nullable errorMessage))completion;

# pragma mark - Misc

- (void)generateSignupTokenForIAPPro:(void (^)(NSDictionary * _Nullable userInfo, BOOL success, NSString * _Nullable errorMessage))completion;

- (void)getDeviceToken:(void (^)(id  _Nullable token, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
