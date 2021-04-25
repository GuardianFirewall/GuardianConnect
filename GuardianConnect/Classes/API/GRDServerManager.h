//
//  GRDServerManager.h
//  Guardian
//
//  Created by will on 6/21/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDHousekeepingAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDServerManager : NSObject

- (void)bindPushToken;
- (void)selectGuardianHostWithCompletion:(void (^)(NSString * _Nullable guardianHost, NSString * _Nullable guardianHostLocation, NSString * _Nullable errorMessage))completion;
- (void)getGuardianHostsWithCompletion:(void (^)(NSArray * _Nullable servers, NSString * _Nullable errorMessage))completion;
+ (NSDictionary *)localRegionFromTimezones:(NSArray *)timezones;
- (void)findSuitableHostAndConnectWithCompletion:(void(^)(NSString *errorMessage, BOOL success))block;
- (void)populateTimezonesIfNecessaryWithCompletion:(void(^_Nullable)(NSArray *regions))block;
- (void)findBestHostInRegion:( NSString * _Nullable )regionName completion:(void(^_Nullable)(NSString *host, NSString *hostLocation, NSString *error))block;
- (void)selectBestHostFromRegion:(NSString *)regionName completion:(void(^_Nullable)(NSString *errorMessage, BOOL success))block;
@end

NS_ASSUME_NONNULL_END
