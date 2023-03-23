//
//  GRDDeviceFilterConfigBlocklist.m
//  GuardianCore
//
//  Created by Constantin Jacob on 17.11.21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDDeviceFilterConfigBlocklist.h"

@interface GRDDeviceFilterConfigBlocklist()
@property (nonatomic, readwrite) NSUInteger bitwiseConfig;
@end

@implementation GRDDeviceFilterConfigBlocklist

- (instancetype)initWithInteger:(NSUInteger)integer {
	self = [super init];
	if (self) {
		self.bitwiseConfig = integer;
	}
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"[GRDDeviceFilterConfigBlocklist] bitwise: %ld; block-none: %@; block-ads: %@; block-phishing: %@", self.bitwiseConfig, [self hasConfig:DeviceFilterConfigBlocklistDisableFirewall] ? @"YES" : @"No", [self hasConfig:DeviceFilterConfigBlocklistBlockAds] ? @"YES" : @"No", [self hasConfig:DeviceFilterConfigBlocklistBlockPhishing] ? @"YES" : @"No"];
}

+ (GRDDeviceFilterConfigBlocklist *)currentBlocklistConfig {
	NSInteger bitwise = [[NSUserDefaults standardUserDefaults] integerForKey:kGRDDeviceFilterConfigBlocklist];
	return [[GRDDeviceFilterConfigBlocklist alloc] initWithInteger:(NSUInteger)bitwise];
}

- (BOOL)blocklistEnabled {
	NSDictionary *apiPortableDict = [self apiPortableBlocklist];
	return [[apiPortableDict allValues] containsObject:@(YES)];
}

- (NSDictionary *)apiPortableBlocklist {
	NSMutableDictionary *apiDict = [NSMutableDictionary new];
	[apiDict setObject:@([self hasConfig:DeviceFilterConfigBlocklistDisableFirewall]) forKey:[self apiKeyForDeviceFilterConfigBlocklist:DeviceFilterConfigBlocklistDisableFirewall]];
	[apiDict setObject:@([self hasConfig:DeviceFilterConfigBlocklistBlockAds]) forKey:[self apiKeyForDeviceFilterConfigBlocklist:DeviceFilterConfigBlocklistBlockAds]];
	 [apiDict setObject:@([self hasConfig:DeviceFilterConfigBlocklistBlockPhishing]) forKey:[self apiKeyForDeviceFilterConfigBlocklist:DeviceFilterConfigBlocklistBlockPhishing]];
	return [NSDictionary dictionaryWithDictionary:apiDict];
}

- (void)setConfig:(DeviceFilterConfigBlocklist)config enabled:(BOOL)enabled {
	if (enabled == YES) {
		[self addConfig:config];
		
	} else {
		[self removeConfig:config];
	}
	
	[[NSUserDefaults standardUserDefaults] setInteger:self.bitwiseConfig forKey:kGRDDeviceFilterConfigBlocklist];
}

- (BOOL)hasConfig:(DeviceFilterConfigBlocklist)config {
	return (self.bitwiseConfig & config) != 0;
}

- (void)addConfig:(DeviceFilterConfigBlocklist)config {
	self.bitwiseConfig = (self.bitwiseConfig |= config);
}

- (void)removeConfig:(DeviceFilterConfigBlocklist)config {
	self.bitwiseConfig = (self.bitwiseConfig &= ~config);
}

- (NSString *)titleForDeviceFilterConfigBlocklist:(DeviceFilterConfigBlocklist)config {
	if (config == DeviceFilterConfigBlocklistDisableFirewall) {
		return @"Disable Firewall";
	
	} else if (config == DeviceFilterConfigBlocklistBlockAds) {
		return @"Block Ads";
		
	} else if (config == DeviceFilterConfigBlocklistBlockPhishing) {
		return @"Block Phishing";
	}
	
	NSString *names = [NSString new];
	for (DeviceFilterConfigBlocklist config = DeviceFilterConfigBlocklistDisableFirewall; config < DeviceFilterConfigBlocklistMax; config <<= 1) {
		names = [names stringByAppendingFormat:@" | %@", [self titleForDeviceFilterConfigBlocklist:config]];
	}
	return names;
}

- (NSString * _Nullable)apiKeyForDeviceFilterConfigBlocklist:(DeviceFilterConfigBlocklist)config {
	NSString *apiKey;
	if (config == DeviceFilterConfigBlocklistDisableFirewall) {
		apiKey = @"block-none";
	
	} else if (config == DeviceFilterConfigBlocklistBlockAds) {
		apiKey = @"block-ads";
		
	} else if (config == DeviceFilterConfigBlocklistBlockPhishing) {
		apiKey = @"block-phishing";
	}
	
	return apiKey;
}


# pragma mark - API Wrapper

- (void)syncBlocklistWithCompletion:(void (^)(NSError * _Nullable))completion {
	GRDCredential *mainCreds = [GRDCredentialManager mainCredentials];
	if (mainCreds == nil) {
		if (completion) completion(nil);
		return;
	}
	
	[[GRDGatewayAPI new] setDeviceFilterConfigsForDeviceId:[mainCreds clientId] apiToken:[mainCreds apiAuthToken] deviceConfigFilters:[self apiPortableBlocklist] completion:^(NSError * _Nullable errorMessage) {
		if (completion) completion(errorMessage);
	}];
}


@end
