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
        self.continent 		= regionDict[@"continent"]; 		// ie europe
		self.countryISOCode = regionDict[@"country-iso-code"]; 	// ie ES
        self.regionName 	= regionDict[@"name"]; 				// ie eu-es
        self.displayName 	= regionDict[@"name-pretty"]; 		// ie Spain
        self.isAutomatic 	= false;
    }
    return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"continent: %@; country-ISO-code: %@; regionName: %@; displayName: %@; is-automatic: %@", self.continent, self.countryISOCode, self.regionName, self.displayName, self.isAutomatic ? @"YES" : @"NO"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	if (self) {
		self.continent 		= [coder decodeObjectForKey:@"continent"];
		self.countryISOCode = [coder decodeObjectForKey:@"country-iso-code"];
		self.regionName 	= [coder decodeObjectForKey:@"name"];
		self.displayName 	= [coder decodeObjectForKey:@"name-pretty"];
		self.isAutomatic 	= [[coder decodeObjectForKey:@"is-automatic"] boolValue];
	}
	
	return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeObject:self.continent forKey:@"continent"];
	[coder encodeObject:self.countryISOCode forKey:@"country-iso-code"];
	[coder encodeObject:self.regionName forKey:@"name"];
	[coder encodeObject:self.displayName forKey:@"name-pretty"];
	[coder encodeObject:[NSNumber numberWithBool:self.isAutomatic] forKey:@"is-automatic"];
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
    [[GRDServerManager new] findBestHostInRegion:self.regionName completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
        if (!error) {
            if (completion) {
                self.bestHost = host;
                self.bestHostLocation = hostLocation;
                completion(host, hostLocation, true);
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
	[serverManager findBestHostInRegion:self.regionName completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
		if (!error) {
			if (completion) {
				self.bestHost = host;
				self.bestHostLocation = hostLocation;
				completion(host, hostLocation, true);
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
