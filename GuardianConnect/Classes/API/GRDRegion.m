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
        self.continent 					= regionDict[@"continent"];
		self.country 					= regionDict[@"country"];
		self.countryISOCode 			= regionDict[@"country-iso-code"];
        self.regionName 				= regionDict[@"name"];
        self.displayName 				= regionDict[@"name-pretty"];
        self.isAutomatic 				= false;
		self.regionPrecision 			= regionDict[@"region-precision"];
		self.latitude					= regionDict[@"latitude"];
		self.longitude					= regionDict[@"longitude"];
		self.serverCount				= regionDict[@"server-count"];
		self.smartRoutingProxyServers 	= regionDict[@"smart-routing-proxy-servers"];
		self.smartRoutingProxyState 	= regionDict[@"smart-routing-proxy-state"];
		
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
	NSUInteger citiesCount = 0;
	if (self.cities != nil) {
		citiesCount = [self.cities count];
	}
	
	return [NSString stringWithFormat:@"continent: %@; country-ISO-code: %@; regionName: %@; displayName: %@; is-automatic: %@; latitude: %@; longitude: %@; cities-count: %ld; time-zone-name: %@", self.continent, self.countryISOCode, self.regionName, self.displayName, self.isAutomatic ? @"YES" : @"NO", self.latitude, self.longitude, citiesCount, self.timeZoneName];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	self = [super init];
	if (self) {
		self.continent 					= [coder decodeObjectForKey:@"continent"];
		self.country 					= [coder decodeObjectForKey:@"country"];
		self.countryISOCode 			= [coder decodeObjectForKey:@"country-iso-code"];
		self.regionName 				= [coder decodeObjectForKey:@"name"];
		self.displayName 				= [coder decodeObjectForKey:@"name-pretty"];
		self.isAutomatic 				= [[coder decodeObjectForKey:@"is-automatic"] boolValue];
		self.regionPrecision 			= [coder decodeObjectForKey:@"region-precision"];
		self.latitude 					= [coder decodeObjectForKey:@"latitude"];
		self.longitude					= [coder decodeObjectForKey:@"longitude"];
		self.serverCount				= [coder decodeObjectForKey:@"server-count"];
		self.cities						= [coder decodeObjectForKey:@"cities"];
		self.timeZoneName				= [coder decodeObjectForKey:@"time-zone-name"];
		self.smartRoutingProxyServers 	= [coder decodeObjectForKey:@"smart-routing-proxy-servers"];
		self.smartRoutingProxyState 	= [coder decodeObjectForKey:@"smart-routing-proxy-state"];
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
	[coder encodeObject:self.timeZoneName forKey:@"time-zone-name"];
	[coder encodeObject:self.smartRoutingProxyServers forKey:@"smart-routing-proxy-servers"];
	[coder encodeObject:self.smartRoutingProxyState forKey:@"smart-routing-proxy-state"];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

// Overriding equality check because we might be missint contitent
// if we are recreated by GRDVPNHelper during credential loading.
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]) {
        return false;
    }
	
	return ([self.regionName isEqualToString:[object regionName]] && [self.displayName isEqualToString:[object displayName]]);
}

+ (GRDRegion *)automaticRegion {
	GRDRegion *reg = [[GRDRegion alloc] init];
	[reg setDisplayName:NSLocalizedString(@"Automatic", nil)];
	[reg setIsAutomatic:true];
	return reg;
}

+ (GRDRegion *)failSafeRegionForRegionPrecision:(NSString *)precision {
	GRDRegion *region = [GRDRegion new];
	
	if ([precision isEqualToString:kGRDRegionPrecisionDefault]) {
		[region setContinent:@"North-America"];
		[region setCountry:@"USA"];
		[region setCountryISOCode:@"US"];
		[region setRegionName:@"us-east"];
		[region setDisplayName:@"USA (East)"];
		[region setIsAutomatic:NO];
		[region setRegionPrecision:precision];
		[region setLatitude:[NSNumber numberWithDouble:36.51503161797652]];
		[region setLongitude:[NSNumber numberWithDouble:-82.25735946455545]];
		
	} else if ([precision isEqualToString:kGRDRegionPrecisionCity] || [precision isEqualToString:kGRDRegionPrecisionCityByCountry]) {
		[region setContinent:@"North-America"];
		[region setCountry:@"USA"];
		[region setCountryISOCode:@"US"];
		[region setRegionName:@"us-nyc"];
		[region setDisplayName:@"New York City"];
		[region setIsAutomatic:NO];
		[region setRegionPrecision:precision];
		[region setLatitude:[NSNumber numberWithDouble:40.714292433330336]];
		[region setLongitude:[NSNumber numberWithDouble:-74.00615560237677]];
		
	} else if ([precision isEqualToString:kGRDRegionPrecisionCountry]) {
		[region setContinent:@"North-America"];
		[region setCountry:@"USA"];
		[region setCountryISOCode:@"US"];
		[region setRegionName:@"na-usa"];
		[region setDisplayName:@"USA"];
		[region setIsAutomatic:NO];
		[region setRegionPrecision:precision];
		[region setLatitude:[NSNumber numberWithDouble:39.338586642335414]];
		[region setLongitude:[NSNumber numberWithDouble:-101.69432971778862]];
	}
	
	return region;
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
