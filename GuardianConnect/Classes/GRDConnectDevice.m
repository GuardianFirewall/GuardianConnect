//
//  GRDConnectDevice.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDConnectDevice.h"

@implementation GRDConnectDevice

- (instancetype)initFromDictionary:(NSDictionary *)deviceDictionary {
	self = [super init];
	if (self) {
		self.nickname = [deviceDictionary objectForKey:kGuardianConnectDeviceNicknameKey];
		self.uuid = [deviceDictionary objectForKey:kGuardianConnectDeviceUUIDKey];
		self.peToken = [deviceDictionary objectForKey:kGuardianConnectDevicePETokenKey];
		
		NSNumber *petExpires = [deviceDictionary objectForKey:kGuardianConnectDevicePETExpiresKey];
		self.petExpires = [NSDate dateWithTimeIntervalSince1970:[petExpires integerValue]];
		
		NSNumber *createdAtUnix = [deviceDictionary objectForKey:kGuardianConnectDeviceCreatedAtKey];
		self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdAtUnix integerValue]];
	}
	
	return self;
}

+ (void)addConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(GRDConnectDevice * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] addConnectDeviceWith:peToken nickname:nickname acceptedTOS:acceptedTOS andCompletion:^(NSDictionary * _Nullable deviceDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectDevice *newDevice = [[GRDConnectDevice alloc] initFromDictionary:deviceDetails];
		if (completion) completion(newDevice, nil);
		return;
	}];
}

- (void)updateConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)newNickname andCompletion:(void (^)(GRDConnectDevice * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] updateConnectDevice:self.uuid withPEToken:peToken nickname:newNickname andCompletion:^(NSDictionary * _Nullable deviceDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectDevice *updatedDevice = [[GRDConnectDevice alloc] initFromDictionary:deviceDetails];
		if (completion) completion(updatedDevice, nil);
		return;
	}];
}

+ (void)listConnectDevicesForPEToken:(NSString *)peToken withCompletion:(void (^)(NSArray<GRDConnectDevice *> * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] listConnectDevicesFor:peToken withCompletion:^(NSArray * _Nullable devices, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		NSMutableArray *parsedDevices = [NSMutableArray new];
		for (NSDictionary *deviceDict in devices) {
			GRDConnectDevice *device = [[GRDConnectDevice alloc] initFromDictionary:deviceDict];
			[parsedDevices addObject:device];
		}
		
		if (completion) completion(parsedDevices, nil);
		return;
	}];
}

- (void)deleteDeviceWithPEToken:(NSString *)peToken andCompletion:(void (^)(NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] deleteConnectDevice:self.uuid withPEToken:peToken andCompletion:^(NSString * _Nullable errorMessage) {
		if (completion) completion(errorMessage);
		return;
	}];
}

@end
