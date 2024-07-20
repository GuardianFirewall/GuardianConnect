//
//  GRDRegion.m
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDRegion.h"
#import <GuardianConnect/GRDServerManager.h>

@implementation GRDRegion

- (instancetype)initWithDictionary:(NSDictionary *)regionDict {
    self = [super init];
    if (self) {
        self.continent 			= regionDict[@"continent"];
		self.country 			= regionDict[@"country"];
		self.countryISOCode 	= regionDict[@"country-iso-code"];
        self.regionName 		= regionDict[@"name"];
        self.displayName 		= regionDict[@"name-pretty"];
        self.isAutomatic 		= false;
		self.regionPrecision 	= regionDict[@"region-precision"];
		self.latitude			= regionDict[@"latitude"];
		self.longitude			= regionDict[@"longitude"];
		self.serverCount		= regionDict[@"server-count"];
		
		NSArray *rawCities = regionDict[@"cities"];
		NSMutableArray *cities = [NSMutableArray new];
		if (rawCities != nil && [rawCities count] > 0) {
			for (NSDictionary *rawCity in rawCities) {
				GRDRegion *cityRegion = [[GRDRegion alloc] initWithDictionary:rawCity];
				[cities addObject:cityRegion];
			}
			
			if ([cities count] > 0) {
				self.cities = cities;
			}
		}
    }
    return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"continent: %@; country-ISO-code: %@; regionName: %@; displayName: %@; is-automatic: %@", self.continent, self.countryISOCode, self.regionName, self.displayName, self.isAutomatic ? @"YES" : @"NO"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	if (self) {
		self.continent 			= [coder decodeObjectForKey:@"continent"];
		self.country 			= [coder decodeObjectForKey:@"country"];
		self.countryISOCode 	= [coder decodeObjectForKey:@"country-iso-code"];
		self.regionName 		= [coder decodeObjectForKey:@"name"];
		self.displayName 		= [coder decodeObjectForKey:@"name-pretty"];
		self.isAutomatic 		= [[coder decodeObjectForKey:@"is-automatic"] boolValue];
		self.regionPrecision 	= [coder decodeObjectForKey:@"region-precision"];
		self.latitude 			= [coder decodeObjectForKey:@"latitude"];
		self.longitude			= [coder decodeObjectForKey:@"longitude"];
		self.serverCount		= [coder decodeObjectForKey:@"server-count"];
		self.cities				= [coder decodeObjectForKey:@"cities"];
	}
	
	return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeObject:self.continent forKey:@"continent"];
	[coder encodeObject:self.country forKey:@"country"];
	[coder encodeObject:self.countryISOCode forKey:@"country-iso-code"];
	[coder encodeObject:self.regionName forKey:@"name"];
	[coder encodeObject:self.displayName forKey:@"name-pretty"];
	[coder encodeObject:[NSNumber numberWithBool:self.isAutomatic] forKey:@"is-automatic"];
	[coder encodeObject:self.regionPrecision forKey:@"region-precision"];
	[coder encodeObject:self.latitude forKey:@"latitude"];
	[coder encodeObject:self.longitude forKey:@"longitude"];
	[coder encodeObject:self.serverCount forKey:@"server-count"];
	[coder encodeObject:self.cities forKey:@"cities"];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

//overriding equality check because we MIGHT be missint contitent if we are recreated by GRDVPNHelper during credential loading.
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) {
        return false;
    }
	
	return ([self.regionName isEqualToString:[object regionName]] && [self.displayName isEqualToString:[object displayName]]);
}

- (void)findBestServerWithCompletion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))completion {
    [[GRDServerManager new] findBestHostInRegion:self.regionName completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
        if (!error) {
            if (completion) {
                self.bestHost = server.hostname;
                self.bestHostLocation = server.displayName;
                completion(server.hostname, server.displayName, true);
            }
            
        } else {
            if (completion) {
                completion(nil, nil, false);
            }
        }
    }];
}

- (void)findBestServerWithServerFeatureEnvironment:(GRDServerFeatureEnvironment)featureEnv betaCapableServers:(BOOL)betaCapable regionPrecision:(NSString *)regionPrecision completion:(void (^)(NSString * _Nullable, NSString * _Nullable, BOOL))completion {
	GRDServerManager *serverManager = [[GRDServerManager alloc] initWithRegionPrecision:regionPrecision serverFeatureEnvironment:featureEnv betaCapableServers:betaCapable];
	[serverManager findBestHostInRegion:self.regionName completion:^(GRDSGWServer * _Nullable server, NSError * _Nonnull error) {
		if (!error) {
			if (completion) {
				self.bestHost = server.hostname;
				self.bestHostLocation = server.displayName;
				completion(server.hostname, server.displayName, true);
			}
			
		} else {
			if (completion) {
				completion(nil, nil, false);
			}
		}
	}];
}

+ (GRDRegion *)automaticRegion {
	GRDRegion *reg = [[GRDRegion alloc] init];
	[reg setDisplayName:NSLocalizedString(@"Automatic", nil)];
	[reg setIsAutomatic:true];
	return reg;
}

+ (NSArray <GRDRegion*> *)regionsFromTimezones:(NSArray * _Nullable)regions {
    __block NSMutableArray *newRegions = [NSMutableArray new];
    [regions enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GRDRegion *region = [[GRDRegion alloc] initWithDictionary:obj];
        if (region) {
            [newRegions addObject:region];
        }
    }];
    return [newRegions sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:true]]];
}

@end
