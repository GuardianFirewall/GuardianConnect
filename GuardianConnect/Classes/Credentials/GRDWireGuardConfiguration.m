//
//  GRDWireGuardConfiguration.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 17.03.22.
//  Copyright © 2022 Sudo Security Group Inc. All rights reserved.
//

#import "GRDWireGuardConfiguration.h"

#import <GuardianConnect/GRDSGWServer.h>

@implementation GRDWireGuardConfiguration


+ (NSString *)wireguardQuickConfigForCredential:(GRDCredential *)credential dnsSRPEnabled:(BOOL)dnsSRPEnabled dnsServers:(NSString *_Nullable)dnsServers sgwServerAddressOverride:(NSString *_Nullable)addressOverride {
	if ([credential transportProtocol] != TransportWireGuard) {
		GRDErrorLogg(@"Main credential is not a WireGuard credential.");
		return nil;
	}
	
	if ([credential devicePublicKey] == nil || [[credential devicePublicKey] isEqualToString:@""] || [credential devicePrivateKey] == nil || [[credential devicePrivateKey] isEqualToString:@""] || [credential IPv4Address] == nil || [[credential IPv4Address] isEqualToString:@""] || [credential serverPublicKey] == nil || [[credential serverPublicKey] isEqualToString:@""] || [credential hostname] == nil || [[credential hostname] isEqualToString:@""]) {
		GRDErrorLog(@"Required credential information missing. Aborting because a valid configuration can't be created!");
		return nil;
	}
	
	if (dnsServers == nil || [dnsServers isEqualToString:@""]) {
		dnsServers = @"1.1.1.1, 1.0.0.1";
	}
	
	if ([credential.server smartProxyRoutingEnabled] && dnsSRPEnabled) {
		dnsServers = @"10.183.10.11";
		if ([[credential.server.region countryISOCode] isEqualToString:@"UK"]) {
			dnsServers = @"10.183.10.12";
		}
	}
	
	NSString *config = @"[Interface]\n";
	config = [config stringByAppendingString:[NSString stringWithFormat:@"PrivateKey = %@\n", [credential devicePrivateKey]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"Address = %@\n", [credential IPv4Address]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"DNS = %@\n", dnsServers]];
	config = [config stringByAppendingString:@"\n"];
	config = [config stringByAppendingString:@"[Peer]\n"];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"PublicKey = %@\n", [credential serverPublicKey]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"AllowedIPs = 0.0.0.0/0, ::/0\n"]];
	// Stealth Mode (GRD-1391): use the caller-supplied endpoint host (a direct IP) when provided so
	// WireGuardKit does not resolve the FQDN via DNS; otherwise fall back to the credential hostname
	// exactly as before. The wg Endpoint accepts a literal IP or a hostname.
	NSString *endpointHost = (addressOverride != nil && addressOverride.length > 0) ? addressOverride : [credential hostname];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"Endpoint = %@:51821", endpointHost]];
	config = [config stringByAppendingString:@"\n"];
	
	GRDDebugLog(@"Formatted WireGuard config: \n%@", config);
	return config;
}


@end
