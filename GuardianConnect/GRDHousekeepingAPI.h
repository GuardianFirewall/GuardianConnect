//
//  GRDHousekeepingAPI.h
//  Guardian
//
//  Created by Constantin Jacob on 18.11.19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>
#import "GRDGatewayAPIResponse.h"
#import "GRDVPNHelper.h"

#define kHousekeepingAPIBase @"https://housekeeping.sudosecuritygroup.com"

NS_ASSUME_NONNULL_BEGIN

@interface GRDHousekeepingAPI : NSObject

/// Validation Method used to obtain a signed JWT from housekeeping
typedef NS_ENUM(NSInteger, GRDHousekeepingValidationMethod) {
    ValidationMethodUsernamePassword,
    ValidationMethodAppStoreReceipt,
    ValidationMethodPromoCode,
    ValidationMethodFreeUser,
    ValidationmethodPEToken
};

/// ValidationMethod to use for the request to housekeeping
/// Currently not used for anything since the validation method is passed to the method directly as a parameter
@property GRDHousekeepingValidationMethod validationMethod;

/// username to be used for authentication when GRDHousekeepingValidationMethod is set to ValidationMethodUsernamePassword
@property NSString *username;

/// password to be used for authentication when GRDHousekeepingValidationMethod is set to ValidationMethodUsernamePassword
@property NSString *password;

/// Digital App Store Receipt used to obtain a signed JWT from housekeeping
/// Currently not used since the App Store Receipt is encoded and sent to housekeeping directly from the method itself. Meant as debugging/manual override option in the future
@property NSString *appStoreReceipt;

/// Promo code to be used to obtain a signed JWT from housekeeping when GRDHousekeepingValidationMethod is set to ValidationMethodPromoCode
@property NSString *promoCode;

/// endpoint: /api/v1/users/info-for-pe-token
/// @param token password equivalent token for which to request information for
/// @param completion completion block returning NSDictionary with information for the requested token, an error message and a bool indicating success of the request
- (void)requestPETokenInformationForToken:(NSString *)token completion:(void (^)(NSDictionary * _Nullable peTokenInfo, NSString * _Nullable errorMessage, BOOL success))completion;

/// endpoint: /api/v1.1/verify-receipt
/// Used to verify the current subscription status of a user if they subscribed through an in app purchase. Returns an array containing only valid subscriptions / purchases
/// @param completion completion block returning array only containing valid subscriptions / purchases, success indicator and a error message containing actionable information for the user if the request failed
- (void)verifyReceiptWithCompletion:(void (^)(NSArray *_Nullable validLineItems, BOOL success, NSString *_Nullable errorMessage))completion;

/// endpoint: /api/v1/subscriber-credential/create
/// Used to obtain a signed JWT from housekeeping for later authentication with zoe-agent
/// @param validationMethod set to determine how to authenticate with housekeeping
/// @param completion completion block returning a signed JWT, indicating request success and a user actionable error message if the request failed
- (void)createNewSubscriberCredentialWithValidationMethod:(GRDHousekeepingValidationMethod)validationMethod completion:(void (^)(NSString * _Nullable subscriberCredential, BOOL success, NSString * _Nullable errorMessage))completion;

- (void)generateSignupTokenForIAPPro:(void (^)(NSDictionary * _Nullable userInfo, BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1/servers/timezones-for-regions
/// Used to obtain all known timezones
/// @param timestamp Unix timestamp containing the last known time timezones were updated. housekeeping will only send timezones if any record has been changed server side
/// @param completion completion block returning an array with all timezones, indicating request success, and the response status code
- (void)requestTimeZonesForRegionsWithTimestamp:(NSNumber *)timestamp completion:(void (^)(NSArray  * _Nullable timeZones, BOOL success, NSUInteger responseStatusCode))completion;

/// endpoint: /api/v1/servers/hostnames-for-region
/// @param region the selected region for which hostnames should be returned
/// @param completion completion block returning an array of servers and indicating request success
- (void)requestServersForRegion:(NSString *)region completion:(void (^)(NSArray *servers, BOOL success))completion;

/// endpint: /api/v1/servers/all-hostnames
/// @param completion completion block returning an array of all hostnames and indicating request success
- (void)requestAllHostnamesWithCompletion:(void (^)(NSArray * _Nullable allServers, BOOL success))completion;

/// endpoint: /api/v1.1/is-eligible-for-free
/// @param completion completion block returning eligible and success BOOL indicating if the user is allowed to connect and whether or not the request was successful
- (void)isEligibleForExtendedFreeWithCompletion:(void (^)(BOOL success, BOOL oldStyleTrialBalance, BOOL eligibleForTrialBalance, NSInteger trialBalance, NSString * _Nullable peToken, NSInteger petExpirationDate, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1/users/login
/// Used for pro/visionary authentication
/// @param email address used to authenticate
/// @param password used to authenticate
/// @param completion completion block that will return a dictionary of authentication data and a boolean for whether or not (API call & authentication) were successful
- (void)loginUserWithEMail:(NSString *)email password:(NSString *)password completion:(void (^)(NSDictionary * _Nullable response, NSString * _Nullable errorMessage, BOOL success))completion;

/// endpoint: /api/v1/users/sign-out
/// Used to mark login PETs as disabled so that they can't be used again
/// @param petoken Password Equivalent Token that is supposed to be marked as disabled
/// @param completion completion block that will return a BOOL indicating successful API call and in the case of a failed API call an error message
- (void)signoutUserPET:(NSString *)petoken completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;

/// endpoint: /api/v1/servers/all-server-regions
/// Used to retrieve all available Server Regions from housekeeping to allow users to override the selected Server Region
/// @param completion completion block returning an array contain a dictionary for each server region and a BOOL indicating a successful API call
- (void)requestAllServerRegions:(void (^)(NSArray <NSDictionary *> * _Nullable items, BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
