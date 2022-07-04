//
//  GRDWireGuardConfiguration.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 17.03.22.
//  Copyright © 2022 Sudo Security Group Inc. All rights reserved.
//

#import "GRDWireGuardConfiguration.h"

@implementation GRDWireGuardConfiguration


+ (NSString *)wireguardQuickConfigForCredential:(GRDCredential *)credential dnsServers:(NSString *_Nullable)dnsServers {
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
	
	NSString *config = @"[Interface]\n";
	config = [config stringByAppendingString:[NSString stringWithFormat:@"PrivateKey = %@\n", [credential devicePrivateKey]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"Address = %@\n", [credential IPv4Address]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"DNS = %@\n", dnsServers]];
	config = [config stringByAppendingString:@"\n"];
	config = [config stringByAppendingString:@"[Peer]\n"];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"PublicKey = %@\n", [credential serverPublicKey]]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"AllowedIPs = 0.0.0.0/0\n"]];
	config = [config stringByAppendingString:[NSString stringWithFormat:@"Endpoint = %@:51821", [credential hostname]]];
	config = [config stringByAppendingString:@"\n"];
	
	GRDDebugLog(@"Formatted WireGuard config: \n%@", config);
	return config;
}


@end
