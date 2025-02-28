//
//  GRDCredential.m
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDCredential.h>
#import <GuardianConnect/GRDGatewayAPI.h>
#import <GuardianConnect/NSDate+Extras.h>
#import <GuardianConnect/GRDSGWServer.h>

@interface GRDCredential() {
    BOOL _checkedExpiration;
    BOOL _expired;
}
@end

@implementation GRDCredential

- (instancetype)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict server:(GRDSGWServer *)server validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds {
	self = [super init];
	if (self) {
		self.identifier 	= [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
		self.name 			= [self defaultFileName];
		self.mainCredential = mainCreds;
		if (mainCreds) {
			self.identifier = @"main";
		}
		self.apiAuthToken 			= credDict[kKeychainStr_APIAuthToken];
		self.expirationDate 		= [[NSDate date] dateByAddingDays:validForDays];
		self.hostname 				= server.hostname;
		self.server 		= server;
		self.hostnameDisplayValue 	= server.displayName;
		
		self.region = server.region;
		
		_checkedExpiration = false;
		_expired = false;
		
		self.transportProtocol = protocol;
		if (protocol == TransportIKEv2) {
			self.username 			= credDict[kKeychainStr_EapUsername];
			self.password 			= credDict[kKeychainStr_EapPassword];
			
			// For IKEv2 the EAP Username is also the client id
			self.clientId = self.username;
			
		} else if (protocol == TransportWireGuard) {
			self.devicePublicKey	= credDict[kGRDWGDevicePublicKey];
			self.devicePrivateKey	= credDict[kGRDWGDevicePrivateKey];
			self.serverPublicKey 	= credDict[kGRDWGServerPublicKey];
			self.IPv4Address 		= credDict[kGRDWGIPv4Address];
			self.IPv6Address 		= credDict[kGRDWGIPv6Address];
			self.clientId 			= credDict[kGRDClientId];
			
			// Note from CJ 2022-03-17:
			// This is only required to ensure backwards compatiblity
			// with other checks in GuardianConnect.
			self.password = @"wireguard-creds";
            self.username = credDict[kGRDClientId];
		}
		
		[self _checkExpiration];
	}
	
	return self;
}

- (void)_checkExpiration {
    if ([[NSDate date] compare:self.expirationDate] == NSOrderedDescending) {
        _expired = true;
    }
    _checkedExpiration = true;
}

- (NSInteger)daysLeft {
    return [self.expirationDate daysUntil];
}

- (BOOL)expired {
    if (!_checkedExpiration) {
        [self _checkExpiration];
    }
    return _expired;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [super init];
    if (self) {
		self.name 					= [aDecoder decodeObjectForKey:@"name"];
		self.identifier 			= [aDecoder decodeObjectForKey:@"identifier"];
		self.expirationDate 		= [aDecoder decodeObjectForKey:@"expirationDate"];
		self.server					= [aDecoder decodeObjectForKey:@"sgwServer"];
		self.hostname 				= [aDecoder decodeObjectForKey:@"hostname"];
		self.hostnameDisplayValue 	= [aDecoder decodeObjectForKey:@"hostnameDisplayValue"];
		self.region 				= [aDecoder decodeObjectForKey:@"region"];
		self.apiAuthToken 			= [aDecoder decodeObjectForKey:@"apiAuthToken"];
		self.transportProtocol		= [[aDecoder decodeObjectForKey:@"transportProtocol"] integerValue];
		
        self.username 				= [aDecoder decodeObjectForKey:@"username"];
		self.password 				= [aDecoder decodeObjectForKey:@"password"];
        
		self.devicePublicKey		= [aDecoder decodeObjectForKey:@"devicePublicKey"];
		self.devicePrivateKey 		= [aDecoder decodeObjectForKey:@"devicePrivateKey"];
		self.serverPublicKey		= [aDecoder decodeObjectForKey:@"serverPublicKey"];
		self.IPv4Address			= [aDecoder decodeObjectForKey:@"IPv4Address"];
		self.IPv6Address			= [aDecoder decodeObjectForKey:@"IPv6Address"];
		self.clientId				= [aDecoder decodeObjectForKey:@"clientId"];
        
        self.mainCredential 		= [aDecoder decodeBoolForKey:@"mainCredential"];
		
		// Note from CJ 2022-03-23:
		// Only load the credential password reference for the main credential
		// since it needs to be available to setup the NEVPNProtocolIKEv2.
		// Everything can stay in the data blob that is stored as one in
		// the keychain as the 'kGuardianCredentialsList'
		if (self.mainCredential == true) {
			self.passwordRef = [GRDKeychain getPasswordRefForAccount:self.identifier];
		}
    }
	
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
	[aCoder encodeObject:self.name forKey:@"name"];
	[aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.expirationDate forKey:@"expirationDate"];
	[aCoder encodeObject:self.server forKey:@"sgwServer"];
	[aCoder encodeObject:self.hostname forKey:@"hostname"];
	[aCoder encodeObject:self.hostnameDisplayValue forKey:@"hostnameDisplayValue"];
	[aCoder encodeObject:self.region forKey:@"region"];
	[aCoder encodeObject:self.apiAuthToken forKey:@"apiAuthToken"];
	[aCoder encodeObject:[NSNumber numberWithInteger:self.transportProtocol] forKey:@"transportProtocol"];
	
	[aCoder encodeObject:self.username forKey:@"username"];
	[aCoder encodeObject:self.password forKey:@"password"];
	
	[aCoder encodeObject:self.devicePublicKey forKey:@"devicePublicKey"];
	[aCoder encodeObject:self.devicePrivateKey forKey:@"devicePrivateKey"];
	[aCoder encodeObject:self.serverPublicKey forKey:@"serverPublicKey"];
	[aCoder encodeObject:self.IPv4Address forKey:@"IPv4Address"];
	[aCoder encodeObject:self.IPv6Address forKey:@"IPv6Address"];
	[aCoder encodeObject:self.clientId forKey:@"clientId"];
	
    [aCoder encodeBool:self.mainCredential forKey:@"mainCredential"];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

//the only thing the user can change is the name
- (void)updateWithItem:(GRDCredential *)cred {
    self.name = cred.name;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    GRDCredential *cred = [[GRDCredential allocWithZone:zone] init];
	cred.name 					= self.name;
	cred.identifier 			= self.identifier;
	cred.expirationDate 		= self.expirationDate;
	cred.hostname 				= self.hostname;
	cred.hostnameDisplayValue 	= self.hostnameDisplayValue;
	cred.apiAuthToken 			= self.apiAuthToken;
	cred.transportProtocol		= self.transportProtocol;
	
	cred.username 				= self.username;
    cred.password 				= self.password;
    
	cred.devicePublicKey		= self.devicePublicKey;
	cred.devicePrivateKey		= self.devicePrivateKey;
	cred.serverPublicKey		= self.serverPublicKey;
	cred.IPv4Address			= self.IPv4Address;
	cred.IPv6Address			= self.IPv6Address;
	cred.clientId				= self.clientId;
    
    cred.mainCredential 		= self.mainCredential;
    return cred;
}

- (NSString *)description {
    NSString *desc = [super description];
    return [NSString stringWithFormat:@"%@\ntransport-protocol: %@\nusername: %@\nhostname: %@\nexpirationDate: %@\nidentifier: %@", desc, [GRDTransportProtocol transportProtocolStringFor:self.transportProtocol], self.username, self.hostname, self.expirationDate, self.identifier];
}

- (NSString *)truncatedHost {
    return [[self.hostname stringByDeletingPathExtension] stringByDeletingPathExtension];
}

- (NSString *)prettyHost {
    return [[[self truncatedHost] stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
}

- (NSString *)defaultFileName {
    NSString *displayHost = [self hostnameDisplayValue] ? [self hostnameDisplayValue] : [NSString stringWithFormat:@"Guardian %@", [self prettyHost]];
    return displayHost;
}

- (BOOL)isEqual:(id)object {
	return ([[(GRDCredential *)object identifier] isEqualToString:self.identifier]);
}

- (BOOL)canRevoke {
    return (self.username.length > 0 && self.apiAuthToken.length > 0);
}

- (void)revokeCredentialWithCompletion:(void(^)(NSError * _Nullable error))completion {
    if (self.username.length > 0 && self.apiAuthToken.length > 0) {
		GRDSubscriberCredential *subCred = [GRDSubscriberCredential currentSubscriberCredential];
		if (subCred == nil) {
			if (completion) completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Credential not invalidated, no Subscriber Credential present"]);
			return;
		}
		[[GRDGatewayAPI new] invalidateCredentialsForClientId:self.username apiToken:self.apiAuthToken hostname:self.hostname subscriberCredential:subCred.jwt completion:^(NSError *error) {
            if (completion)completion(error);
        }];
		
    } else {
        GRDWarningLogg(@"Missing data to revoke the VPN credential: %@", self);
        if (completion)completion([GRDErrorHelper errorWithErrorCode:kGRDGenericErrorCode andErrorMessage:@"Cant revoke this credential, missing necessary data!"]);
    }
}

- (GRDSGWServer *)sgwServerFormat {
	GRDSGWServer *server = [GRDSGWServer new];
	server.hostname = self.hostname;
	server.displayName = self.hostnameDisplayValue;
	server.region = self.region;
	
	return server;
}

@end
