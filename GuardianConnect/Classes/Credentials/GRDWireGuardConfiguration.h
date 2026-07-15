//
//  GRDWireGuardConfiguration.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 17.03.22.
//  Copyright © 2022 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GuardianConnect/GRDCredential.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDWireGuardConfiguration : NSObject

/// Retrieve a formatted, wg-quick(8) compatible string for a given GRDCredential
/// Will return nil if the transportProtocol property is not TransportWireGuard
/// @param credential the given credential out which the formatted wg-quick compatible should be generated
/// @param smartProxyRoutingEnabled will set the DNS servers to a private IP space 10.x.x.x available to route to from within the DNS tunnel
/// @param dnsServers allows to set custom DNS servers instead of the standard Cloudflare 1.1.1.1, 1.0.0.1 servers. This option will be ignored if smartProxyRoutingEnabled is enabled
/// @param addressOverride allows for overriding of the peer hostname with an IP address
///
/// Stealth Mode (GRD-1391): pass a direct IP as endpointHostOverride so the WireGuard tunnel dials
/// the server without WireGuardKit performing a DNS lookup of the FQDN (which fails on hostile
/// networks). Pass nil to use credential.hostname exactly as before.
+ (NSString *)wireguardQuickConfigForCredential:(GRDCredential *)credential smartProxyRoutingEnabled:(BOOL)smartProxyRoutingEnabled dnsServers:(NSString *_Nullable)dnsServers sgwServerAddressOverride:(NSString *_Nullable)addressOverride;

@end

NS_ASSUME_NONNULL_END
