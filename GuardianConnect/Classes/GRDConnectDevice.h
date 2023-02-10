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
static NSString * const kGuardianConnectDevicePETokenKey 	= @"ep-grd-device-pe-token";
static NSString * const kGuardianConnectDeviceCreatedAtKey 	= @"ep-grd-device-created-at";


@interface GRDConnectDevice : NSObject

@property NSString 	*nickname;
@property NSString 	*uuid;
@property NSString 	*peToken;
@property NSDate 	*createdAt;

- (instancetype)initFromDictionary:(NSDictionary *)deviceDictionary;

+ (void)addConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(GRDConnectDevice * _Nullable newDevice, NSString * _Nullable errorMessage))completion;

- (void)updateConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)newNickname andCompletion:(void (^)(GRDConnectDevice * _Nullable updatedDevice, NSString * _Nullable errorMessage))completion;

+ (void)listConnectDevicesForPEToken:(NSString *)peToken withCompletion:(void (^)(NSArray <GRDConnectDevice *> * _Nullable devices, NSString * _Nullable errorMessage))completion;

- (void)deleteDeviceWithPEToken:(NSString *)peToken andCompletion:(void (^)(NSString * _Nullable errorMessage))completion;


@end

NS_ASSUME_NONNULL_END
