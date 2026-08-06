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
@property NSString 		*displayName;
@property BOOL 			offline;
@property NSUInteger	capacityScore;
@property NSUInteger 	serverFeatureEnvironment;
@property BOOL			betaCapable;
@property BOOL			smartRoutingProxyEnabled;
@property BOOL 			multihopEntryEnabled;
@property NSString		*ipv4Address;
@property NSString		*ipv6Address;
@property GRDRegion 	*region;


- (instancetype)initFromDictionary:(NSDictionary *)dict;

/// Returns the address that should be used as the VPN dial target (IKEv2 serverAddress /
/// WireGuard Endpoint host) for the given credential.
/// Returns the cached direct IP only when Stealth Mode is enabled AND a cached IP exists for the
/// credential's hostname; otherwise returns credential.hostname unchanged.
/// MITIGATION (GRD-1391): the FQDN fallback guarantees that with Stealth Mode off, or on a cache
/// miss, the dial target is byte-for-byte what it was before this feature existed.
- (NSString *)addressForStealthModeEnabled:(BOOL)stealthModeEnabled;

@end

NS_ASSUME_NONNULL_END
