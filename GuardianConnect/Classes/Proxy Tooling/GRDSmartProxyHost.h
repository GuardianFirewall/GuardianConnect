//
//  GRDSmartProxyHost.h
//  GuardianCore
//
//  Created by Constantin Jacob on 01.09.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDHousekeepingAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDSmartProxyHost : NSObject

@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSNumber *region;
@property BOOL requiresCorrelation;

- (instancetype)initFromDictionary:(NSDictionary *)host;

+ (void)setupSmartProxyHosts:(void (^)(NSError *_Nullable error))completion;
+ (void)requestAllSmartProxyHostsWithCompletion:(void (^)(NSArray <GRDSmartProxyHost*> * _Nullable hosts, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END