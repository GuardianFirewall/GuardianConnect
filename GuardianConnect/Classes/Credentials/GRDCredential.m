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

@interface GRDCredential() {
    BOOL _checkedExpiration;
    BOOL _expired;
}
@end

@implementation GRDCredential

//i dont like this, but i need a unique id for the auth token as well and i dont want to create two completely unique ID's for this
- (NSString *)authTokenIdentifier {
    return [self.identifier stringByAppendingString:@"-authToken"];
}

//used for legacy EAP credentials, APIAuthToken will be empty because we were not saving those details when creating additional EAP's before.
- (id)initWithDictionary:(NSDictionary *)credDict hostname:(NSString *)hostname expiration:(NSDate *)expirationDate {
    self = [super init];
    if (self) {
		self.transportProtocol 	= TransportIKEv2;
        self.identifier 		= [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
        self.username 			= credDict[kKeychainStr_EapUsername];
        self.password 			= credDict[kKeychainStr_EapPassword];
        self.apiAuthToken 		= credDict[kKeychainStr_APIAuthToken];
        self.hostname 			= hostname;
        self.expirationDate 	= expirationDate;
        self.name 				= [self defaultFileName];
        _checkedExpiration 		= false;
        _expired 				= false;
        [self _checkExpiration];
    }
    return self;
}

- (id)initWithFullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds {
    self = [super init];
    if (self) {
		self.transportProtocol 		= TransportIKEv2;
        self.identifier 			= [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
        self.username 				= credDict[kKeychainStr_EapUsername];
        self.password 				= credDict[kKeychainStr_EapPassword];
        self.apiAuthToken 			= credDict[kKeychainStr_APIAuthToken];
        self.hostname 				= credDict[kGRDHostnameOverride];
        self.expirationDate 		= [[NSDate date] dateByAddingDays:validForDays];
        self.hostnameDisplayValue 	= credDict[kGRDVPNHostLocation];
        self.name 					= [self defaultFileName];
        _checkedExpiration 			= false;
        _expired 					= false;
        self.mainCredential = mainCreds;
        if (mainCreds) {
            self.identifier = @"main";
        }
        [self _checkExpiration];
    }
    return self;
}

- (id)initWithTransportProtocol:(TransportProtocol)protocol fullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds {
	self = [super init];
	if (self) {
		self.identifier 	= [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
		self.name 			= [self defaultFileName];
		self.mainCredential = mainCreds;
		if (mainCreds) {
			self.identifier = @"main";
		}
		self.apiAuthToken 			= credDict[kKeychainStr_APIAuthToken];
		self.hostname 				= credDict[kGRDHostnameOverride];
		self.expirationDate 		= [[NSDate date] dateByAddingDays:validForDays];
		self.hostnameDisplayValue 	= credDict[kGRDVPNHostLocation];
		
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

//for testing
- (void)forceExpired {
    _expired = true;
}

- (BOOL)expired {
    if (!_checkedExpiration) { //shouldnt ever happen, but just in case.
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
		self.hostname 				= [aDecoder decodeObjectForKey:@"hostname"];
		self.hostnameDisplayValue 	= [aDecoder decodeObjectForKey:@"hostnameDisplayValue"];
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
	[aCoder encodeObject:self.hostname forKey:@"hostname"];
	[aCoder encodeObject:self.hostnameDisplayValue forKey:@"hostnameDisplayValue"];
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

//since a proper success status is 0, and all we really care about is whether or not it was successful, adding them both together should still == 0 upon success.

- (OSStatus)removeFromKeychain {
    OSStatus stat = [GRDKeychain removeKeychanItemForAccount:[self authTokenIdentifier]];
    stat = stat + [GRDKeychain removeKeychanItemForAccount:self.identifier];
    return stat;
}

- (OSStatus)saveToKeychain {
//    OSStatus stat = [GRDKeychain storePassword:self.apiAuthToken forAccount:[self authTokenIdentifier]];
    OSStatus stat = [GRDKeychain storePassword:self.password forAccount:self.identifier];
    if (!self.passwordRef) {
        self.passwordRef = [GRDKeychain getPasswordRefForAccount:self.identifier];
    }
    return stat;
}

- (BOOL)loadFromKeychain {
    self.password 		= [GRDKeychain getPasswordStringForAccount:self.identifier];
    self.passwordRef 	= [GRDKeychain getPasswordRefForAccount:self.identifier];
//    self.apiAuthToken 	= [GRDKeychain getPasswordStringForAccount:[self authTokenIdentifier]];
    return (self.password && self.apiAuthToken);
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

- (void)revokeCredentialWithCompletion:(void(^)(BOOL success, NSString *errorMessage))completion {
    if (self.username.length > 0 && self.apiAuthToken.length > 0) {
        [[GRDGatewayAPI new] invalidateEAPCredentials:self.username andAPIToken:self.apiAuthToken completion:^(BOOL success, NSString * _Nullable errorMessage) {
            if (success) {
                GRDLog(@"[DEBUG] successfully revoked our credential!");
				
            } else {
                GRDLog(@"[DEBUG] failed to revoke the credential with error: %@", errorMessage);
            }
            if (completion)completion(success, errorMessage);
        }];
		
    } else {
        GRDLog(@"[DEBUG] cant revoke this credential, missing necessary data!");
        if (completion)completion(false, @"Cant revoke this credential, missing necessary data!");
    }
}

@end
