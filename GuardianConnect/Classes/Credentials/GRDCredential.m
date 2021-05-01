//
//  GRDCredential.m
//  Guardian
//
//  Created by Kevin Bradley on 3/2/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDCredential.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDGatewayAPI.h>
#import <GuardianConnect/NSDate+Extras.h>

@interface GRDCredential(){
    BOOL _checkedExpiration;
    BOOL _expired;
}
@end

@implementation GRDCredential

//i dont like this, but i need a unique id for the auth token as well and i dont want to create two completely unique ID's for this
- (NSString *)authTokenIdentifier {
    return [_identifier stringByAppendingString:@"-authToken"];
}

//used for legacy EAP credentials, APIAuthToken will be empty because we were not saving those details when creating additional EAP's before.
- (id)initWithDictionary:(NSDictionary *)credDict hostname:(NSString *)hostname expiration:(NSDate *)expirationDate {
    self = [super init];
    if (self){
        _identifier = [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
        _username = credDict[kKeychainStr_EapUsername];
        _password = credDict[kKeychainStr_EapPassword];
        _apiAuthToken = credDict[kKeychainStr_APIAuthToken];
        _hostname = hostname;
        _expirationDate = expirationDate;
        _name = [self defaultFileName];
        _checkedExpiration = false;
        _expired = false;
        [self _checkExpiration];
    }
    return self;
}

- (id)initWithFullDictionary:(NSDictionary *)credDict validFor:(NSInteger)validForDays isMain:(BOOL)mainCreds {
    self = [super init];
    if (self){
        _identifier = [NSUUID UUID].UUIDString; //used in export configs but also to retrieve passwords
        _username = credDict[kKeychainStr_EapUsername];
        _password = credDict[kKeychainStr_EapPassword];
        _apiAuthToken = credDict[kKeychainStr_APIAuthToken];
        _hostname = credDict[kGRDHostnameOverride];
        _expirationDate = [[NSDate date] dateByAddingDays:validForDays];
        _hostnameDisplayValue = credDict[kGRDVPNHostLocation];
        _name = [self defaultFileName];
        _checkedExpiration = false;
        _expired = false;
        _mainCredential = mainCreds;
        if (mainCreds){
            _identifier = @"main";
        }
        [self _checkExpiration];
    }
    return self;
}

- (void)_checkExpiration {
    if([[NSDate date] compare:_expirationDate] == NSOrderedDescending){
        _expired = true;
    }
    _checkedExpiration = true;
}

- (NSInteger)daysLeft {
    return [_expirationDate daysUntil];
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
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.username = [aDecoder decodeObjectForKey:@"username"];
        self.hostnameDisplayValue = [aDecoder decodeObjectForKey:@"hostnameDisplayValue"];
        self.expirationDate = [aDecoder decodeObjectForKey:@"expirationDate"];
        self.hostname = [aDecoder decodeObjectForKey:@"hostname"];
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.mainCredential = [aDecoder decodeBoolForKey:@"mainCredential"];
        [self loadFromKeychain];
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.username forKey:@"username"];
    [aCoder encodeObject:self.expirationDate forKey:@"expirationDate"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.hostname forKey:@"hostname"];
    [aCoder encodeObject:self.hostnameDisplayValue forKey:@"hostnameDisplayValue"];
    [aCoder encodeBool:self.mainCredential forKey:@"mainCredential"];
}

//the only thing the user can change is the name
- (void)updateWithItem:(GRDCredential *)cred {
    self.name = cred.name;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    GRDCredential *cred = [[GRDCredential allocWithZone:zone] init];
    cred.identifier = self.identifier;
    cred.username = self.username;
    cred.password = self.password;
    cred.name = self.name;
    cred.hostname = self.hostname;
    cred.expirationDate = self.expirationDate;
    cred.hostnameDisplayValue = self.hostnameDisplayValue;
    cred.apiAuthToken = self.apiAuthToken;
    return cred;
}

- (NSString *)description {
    NSString *desc = [super description];
    return [NSString stringWithFormat:@"%@\nusername: %@\nhostname: %@\nexpirationDate: %@\nidentifier: %@", desc, _username, _hostname, _expirationDate, _identifier];
}

//since a proper success status is 0, and all we really care about is whether or not it was successful, adding them both together should still == 0 upon success.

- (OSStatus)removeFromKeychain {
    OSStatus stat = [GRDKeychain removeKeychanItemForAccount:[self authTokenIdentifier]];
    stat = stat + [GRDKeychain removeKeychanItemForAccount:_identifier];
    return stat;
}

- (OSStatus)saveToKeychain {
    OSStatus stat = [GRDKeychain storePassword:_apiAuthToken forAccount:[self authTokenIdentifier]];
    stat = stat + [GRDKeychain storePassword:_password forAccount:_identifier];
    if (!_passwordRef){
        _passwordRef = [GRDKeychain getPasswordRefForAccount:_identifier];
    }
    return stat;
}

- (BOOL)loadFromKeychain {
    _password = [GRDKeychain getPasswordStringForAccount:_identifier];
    _passwordRef = [GRDKeychain getPasswordRefForAccount:_identifier];
    _apiAuthToken = [GRDKeychain getPasswordStringForAccount:[self authTokenIdentifier]];
    return (_password && _apiAuthToken);
}

- (NSString *)truncatedHost {
    return [[_hostname stringByDeletingPathExtension] stringByDeletingPathExtension];
}

- (NSString *)prettyHost {
    return [[[self truncatedHost] stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
}

- (NSString *)defaultFileName {
    NSString *displayHost = [self hostnameDisplayValue] ? [self hostnameDisplayValue] : [NSString stringWithFormat:@"Guardian %@",[self prettyHost]];
    return displayHost;
}


- (BOOL)isEqual:(id)object {
    return ([[object identifier] isEqualToString:self.identifier]);
}


- (BOOL)canRevoke {
    return (self.username.length > 0 && self.apiAuthToken.length > 0);
}

- (void)revokeCredentialWithCompletion:(void(^)(BOOL success, NSString *errorMessage))block {
    if (_username.length > 0 && _apiAuthToken.length > 0){
        [[GRDGatewayAPI new] invalidateEAPCredentials:_username andAPIToken:_apiAuthToken completion:^(BOOL success, NSString * _Nullable errorMessage) {
            if (success){
                GRDLog(@"[DEBUG] successfully revoked our credential!");
            } else {
                GRDLog(@"[DEBUG] failed to revoke the credential with error: %@", errorMessage);
            }
            if (block)block(success, errorMessage);
        }];
    } else {
        GRDLog(@"[DEBUG] cant revoke this credential, missing necessary data!");
        if (block)block(false, @"Cant revoke this credential, missing necessary data!");
    }
}

@end
