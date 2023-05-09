//
//  GRDConnectDevice.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDHousekeepingAPI.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGuardianConnectDeviceNicknameKey 	= @"ep-grd-device-nickname";
static NSString * const kGuardianConnectDeviceUUIDKey 		= @"ep-grd-device-uuid";
static NSString * const kGuardianConnectDeviceCreatedAtKey 	= @"ep-grd-device-created-at";
static NSString * const kGuardianConnectDevicePETokenKey 	= @"pe-token";
static NSString * const kGuardianConnectDevicePETExpiresKey	= @"pet-expires";

static NSString * const kGuardianConnectDevice				= @"kGuardianConnectDevice";

@interface GRDConnectDevice : NSObject <NSSecureCoding>

/// Device nickname. Max length 200 characters
@property NSString 	*nickname;

/// Device UUID assinged by the GuardianConnect API upon creation of the device
@property NSString 	*uuid;

/// The device's PET. Maybe nil
@property NSString 	* _Nullable peToken;

/// The device's PET expiration date. The date is passed as a JSON encoded Unix timestamp in API calls and is computed into an NSDate
@property NSDate 	* _Nullable petExpires;

/// The timestamp at which the device was created. The date is passed as a JSON encoded Unix timestamp in API calls and is computed into an NSDate
@property NSDate 	*createdAt;


/// Convenience method to quickly create a GRDConnectDevice object from a dictionary containing key/value pairs returned by the GuardianConnect API
/// - Parameter deviceDictionary: a dictionary containing key/value pairs that represent a GRDConnectDevice object
- (instancetype)initFromDictionary:(NSDictionary *)deviceDictionary;

/// Convenience method to quickly retrieve the current Connect device object
///
/// This method should only be used in the context of a Connect device being the main user on the device
/// It does not retrieve the device's PE-Token as it should only be fetched if needed from the keychain
/// - Parameter completion: completion block containing the current Connect device or nil if an error occured or no device has been stored yet. In case of a failure to get the current device an error message is provided, otherwise it is nil
+ (void)currentDeviceWithCompletion:(void (^)(GRDConnectDevice * _Nullable_result device, NSError * _Nullable error))completion;

/// Stores an encoded GRDConnectDevice object in NSUserDefaults
///
/// This method should only be used in the context of a Connect device being the main user on the device
/// This method ensures that the device's PET is never written into NSUserDeafults in plaintext and it is instead stored securely on device in the keychain
- (NSError *)store;


# pragma mark - API Wrappers

/// Convenience wrapper around the Connect API endpoint to register a new device for a given Connect subscriber PET.
/// - Parameters:
///   - peToken: the Connect subscribers PET
///   - nickname: the nickname of the device
///   - acceptedTOS: used to indicate that the invited device has accepted the TOS
///   - completion: completion block containing the newly registered Connect device object or nil in case of a failure. If an error occured during the registration process an error message is provided. If no error occurred the errorMessage will be nil
+ (void)addConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(GRDConnectDevice * _Nullable newDevice, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connect API endpoint to update a Connect device's nickname
/// - Parameters:
///   - peToken: the subscribers PET with which this device is associated
///   - newNickname: the new nickname
///   - completion: completion block containing the updated Connect device object or nil in case of a failure. If an error occured during the update process an error message is provided. If no error occurred the errorMessage will be nil
- (void)updateConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)newNickname andCompletion:(void (^)(GRDConnectDevice * _Nullable updatedDevice, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connect API to fetch the list of devices associated with the Connect subscriber account
/// - Parameters:
///   - peToken: the Connect subscriber's PET this device is associated with
///   - completion: completion block containing an array of Connect device objects or nil in case of a failure. If an error occured during the fetch process an error message is provided. If no error occurred the errorMessage will be nil
+ (void)listConnectDevicesForPEToken:(NSString *)peToken withCompletion:(void (^)(NSArray <GRDConnectDevice *> * _Nullable devices, NSError * _Nullable errorMessage))completion;

/// Convenience wrapper around the Connect API endpoint to delete a Connect device permanently. Once complete the Connect device is unable to reconnect as it cannot create new Subscriber Credentials
/// - Parameters:
///   - peToken: the Connect subscriber's PET this device is associated with
///   - completion: completion block containing an error message in case of a failure. If nil is returned the action was successful
- (void)deleteDeviceWithPEToken:(NSString *)peToken andCompletion:(void (^)(NSError * _Nullable errorMessage))completion;


/// Convenience wrapper around the Connect API endpoint to validate the Connect device's PET.
///
/// ! Attention: This method can be used both from a device using a Connect subscriber as the main user (validate the PET of a device associated with this Connect subscriber account) as well as from a device using *this* Connect device as the main user
/// - Parameters:
///   - peToken: the Connect device's PET
///   - completion: completion block containing the validated Connect device object incl. updated PET and PET expiration date or nil in case of a failure. If an error occured during the validation process an error message is provided. If no error occurred the errorMessage will be nil
- (void)validateConnectDeviceWithDevicePEToken:(NSString *)peToken andCompletion:(void (^)(GRDConnectDevice * _Nullable validatedDevice, NSError * _Nullable errorMessage))completion;

@end

NS_ASSUME_NONNULL_END
