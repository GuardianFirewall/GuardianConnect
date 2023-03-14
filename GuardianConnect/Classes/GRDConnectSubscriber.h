//
//  GRDConnectSubscriber.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDConnectDevice.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGuardianConnectSubscriber 								= @"kGuardianConnectSubscriber";
static NSString * const kGuardianConnectSubscriberIdentifierKey 				= @"ep-grd-subscriber-identifier";
static NSString * const kGuardianConnectSubscriberSecretKey 					= @"ep-grd-subscriber-secret";
static NSString * const kGuardianConnectSubscriberEmailKey 						= @"ep-grd-subscriber-email";
static NSString * const kGuardianConnectSubscriberSubscriptionSKUKey 			= @"ep-grd-subscription-sku";
static NSString * const kGuardianConnectSubscriberSubscriptionNameFormattedKey 	= @"ep-grd-subscription-name-formatted";
static NSString * const kGuardianConnectSubscriberSubscriptionExpirationDateKey = @"ep-grd-subscription-expiration-date";
static NSString * const kGuardianConnectSubscriberCreatedAtKey 					= @"ep-grd-subscriber-created-at";


@interface GRDConnectSubscriber : NSObject <NSSecureCoding>

/// Non-secret identifier
@property NSString 	*identifier;

/// Private subscriber secret
@property NSString 	*secret;

/// The subscriber's E-Mail address, if one has been set. This might be nil if none was set by the subscriber
@property NSString 	* _Nullable email;

/// The subscription's SKU (internal) presentation
@property NSString 	*subscriptionSKU;

/// The subscription's formatted name (public)
@property NSString 	*subscriptionNameFormatted;

/// The subscription's expiration date. The date is passed as a JSON encoded Unix timestamp in API calls and is computed into an NSDate
@property NSDate 	*subscriptionExpirationDate;

/// The date the Connect subscriber was first registered. The date is passed as a JSON encoded Unix timestamp in the API calls and is computed into an NSDate
@property NSDate 	*createdAt;


/// Convenience function to quickly create a GRDConnectSubscriber from a dictionary containing key/value pairs returned by the GuardianConnect API
/// - Parameter dict: NSDictionary with decoded from JSON data containing key value pairs that represent a GRDConnectSubscriber object
- (instancetype)initFromDictionary:(NSDictionary * _Nonnull)dict;

/// Retrieves a GRDConnectSubscriber reference from an object stored in NSUserDefaults.
/// - Parameter completion: completion block returning subscriber reference. If no subscriber reference has been created yet both the subscriber & error parameters in the returned completion block will be nil
+ (void)currentSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable_result subscriber, NSError * _Nullable error))completion;

/// Stores an encoded GRDConnectSubscriber object in NSUserDefaults. Ensures that the subscriber's secret is never written into NSUserDeafults in plaintext and instead stores it securely in the keychain
- (NSError * _Nullable)store;

/// Convenience function to clear out any references to a local Connect subscriber on device either useful for debugging purposes or to enable a clean logout functionality on device. ATTENTION: This will also delete any PET and PET expiration date out of the keychain and NSUserDefaults respectively!
+ (NSError * _Nullable)destorySubscriber;

/// Convenience function to retrieve all devices associated with the current subscriber.
/// - Parameter completion: completion block containing the GRDConnectDevice objects as well as an error message. errorMessage will be returned as nil if no error occurred in the process of getting the list of devices
- (void)allDevicesWithCompletion:(void (^)(NSArray <GRDConnectDevice *> * _Nullable devices, NSError * _Nullable errorMessage))completion;


# pragma mark - API Wrappers

/// Convenience wrapper around the Connect API endpoint to quickly register a new GuardianConnect subscriber. If successful the Connect subscriber will be stored automatically on the device
/// - Parameters:
///   - acceptedTOS: indicator to ensure that the new subscriber has accepted the TOS
///   - completion: completion block returning a GRDConnectSubscriber object of the new subscriber if registration was successful. If an error occurred during registration an error message is provided. If no error occured the errorMessage will be nil
- (void)registerNewConnectSubscriber:(BOOL)acceptedTOS withCompletion:(void (^)(GRDConnectSubscriber * _Nullable newSubscriber, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connect API endpoint to quickly update a GuardianConnect subscriber's E-Mail address. If successful the Connect subscriber will be stored automatically on the device
/// - Parameters:
///   - email: The subscriber's E-Mail address
///   - completion: completion block containing the updated GRDConnectSubscriber object if the E-Mail address was updated succesfully. If an error occured during the update process an error message is provided. If no error occurred the errorMessage will be nil
- (void)updateConnectSubscriberWithEmailAddress:(NSString * _Nonnull)email andCompletion:(void (^)(GRDConnectSubscriber * _Nullable subscriber, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connect API endpoint to validate the subscriber's subscription with the help of the subscriber's identifier and secret as well as the PE-Token found in the keychain so that the current PET can be invalidated and a new one can be created for the subscriber. If successful the Connect subscriber will be stored automatically on the device
/// - Parameter completion: completion block containing the validated subscriber object with updated subscription metadata. The updated metadata is stored persistently automatically. If an error occured during validation of the subscription for any reason nil will be returned for the subscriber object and an error message will be provided. If no error occurred the errorMessage will be nil
- (void)validateConnectSubscriberWithCompletion:(void (^)(GRDConnectSubscriber * _Nullable subscriber, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connection API to logout a Connect subscriber and invalidate the subscriber's PE-Token that was active on the device this function was called from
/// - Parameter completion: completion block returning an error if a problem of some sort occurred during the logout attempt. If no error was returned the the logout attempt was successful
- (void)logoutConnectSubscriberWithCompletion:(void (^)(NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
