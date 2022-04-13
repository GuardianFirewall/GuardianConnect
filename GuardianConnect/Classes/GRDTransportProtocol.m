//
//  GRDTransportProtocol.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 05.01.22.
//  Copyright © 2022 Sudo Security Group Inc. All rights reserved.
//

#import "GRDTransportProtocol.h"

@implementation GRDTransportProtocol

+ (NSString *)transportProtocolStringFor:(TransportProtocol)protocol {
	if (protocol == TransportIKEv2) {
		return @"ikev2";
		
	} else if (protocol == TransportWireGuard) {
		return @"wireguard";
	
	} else {
		return @"unknown";
	}
}

+ (NSString *)prettyTransportProtocolStringFor:(TransportProtocol)protocol {
	if (protocol == TransportIKEv2) {
		return @"IKEv2";
		
	} else if (protocol == TransportWireGuard) {
		return @"WireGuard";
	
	} else {
		return @"Unknown";
	}
}

+ (NSString *)setUserPreferredTransportProtocol:(TransportProtocol)protocol {
	if (protocol == TransportUnknown) {
		return @"Not allowed to set TransportUnknown as user preferred transport protocol. Please set it to TransportIKEv2 or TransportWireguard";
	}
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *preferredTransportProtocol = [NSString new];
	if (protocol == TransportIKEv2) {
		preferredTransportProtocol = @"ikev2";
		
	} else if (protocol == TransportWireGuard) {
		preferredTransportProtocol = @"wireguard";
	}
	
	GRDLogg(@"Setting user preferred transport protocol to: %@", preferredTransportProtocol);
	[defaults setObject:preferredTransportProtocol forKey:@"kGuardianTransportProtocol"];
	return nil;
}

+ (TransportProtocol)getUserPreferredTransportProtocol {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *preferredTransportProtocol = [defaults stringForKey:kGuardianTransportProtocol];
	if ([preferredTransportProtocol isEqualToString:@""] || preferredTransportProtocol == nil) {
		GRDWarningLogg(@"No preferred transport protocol set yet. Defaulting to IKEv2");
		return TransportIKEv2;
	}
	
	TransportProtocol transport;
	if ([preferredTransportProtocol isEqualToString:@"ikev2"]) {
		transport = TransportIKEv2;
		
	} else if ([preferredTransportProtocol isEqualToString:@"wireguard"]) {
		transport = TransportWireGuard;
		
	} else {
		transport = TransportUnknown;
	}
	
	return transport;
}

@end
