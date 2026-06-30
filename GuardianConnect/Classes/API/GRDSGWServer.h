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

@interface GRDSGWServer : NSObject <NSSecureCoding>

@property NSString 		*hostname;
/// Direct IPv4 address of the secure gateway, used by Stealth Mode (GRD-1391) to dial
/// the server without a DNS lookup of `hostname`. May be nil if the backend did not
/// supply one; callers must fall back to `hostname` in that case.
/// IPv6 is intentionally not modelled yet — see GRD-1391 future work.
@property NSString 		* _Nullable serverIPv4;
@property NSString 		*displayName;
@property BOOL 			offline;
@property NSUInteger	capacityScore;
@property NSUInteger 	serverFeatureEnvironment;
@property BOOL			betaCapable;
@property BOOL			smartProxyRoutingEnabled;
@property GRDRegion 	*region;


- (instancetype)initFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
