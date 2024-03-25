//
//  GRDServer.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 20.03.24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDRegion.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDSGWServer : NSObject

@property NSString *hostname;
@property NSString *displayName;
@property BOOL 		offline;
@property NSInteger	capacityScore;
@property NSInteger serverFeatureEnvironment;
@property BOOL		betaCapable;
@property BOOL		smartRoutingEnabled;
@property GRDRegion *region;


- (instancetype)initFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
