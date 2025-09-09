//
//  GRDRegion.h
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDRegion : NSObject <NSSecureCoding>

/// Region continent, eg. 'Europe' or 'North-America'
@property NSString *continent;

/// Region country, eg. 'Germany' or 'Canada'
@property NSString *country;

/// Region ISO 3166 1 Alpha 2 country code, eg. 'US' or 'DE'
@property NSString *countryISOCode;

/// Region name, eg. 'us-east' or 'eu-de'
///
/// This is the key that is used to match it up with SGW servers
@property NSString *regionName;

/// Region formated name, eg. 'USA (Central)' or 'Czech-Republic'
@property NSString *displayName;

/// Convenience indicator to easily identify whether this is the automatic region or not
@property BOOL isAutomatic;

/// Region precision indicator
///
/// Can only be one of
/// - kGRDRegionPrecisionDefault
/// - kGRDRegionPrecisionCity
/// - kGRDRegionPrecisionCountry
/// - kGRDRegionPrecisionCityByCountry
@property NSString *regionPrecision;

/// Region latitude to show the location on a map
@property NSNumber *latitude;

/// Region longitude to show the location on a map
@property NSNumber *longitude;

/// The total count of available servers for the current
/// user in any given region
@property NSNumber *serverCount;

/// The amount of secure gateway servers tied to the region
/// which support the smart routing proxy capability
@property NSNumber *smartRoutingProxyServers;

/// A constant indicator representing the state of the smart
/// routing proxy capability support for the region
/// 
/// Eg. if GRDRegion.serverCount == GRDRegion.smartRoutingProxyServers
/// this string will be set to kGRDRegionSmartRoutingProxyAll
///
/// Will be one of
/// - kGRDRegionSmartRoutingProxyNone
/// - kGRDRegionSmartRoutingProxySome
/// - kGRDRegionSmartRoutingProxyAll
@property NSString *smartRoutingProxyState;

/// If the region precision kGRDRegionPrecisionCityByCountry is
/// selected this property will contain an array of regions pointing
/// to cities that are mapped to the country
@property NSArray <GRDRegion *>	*cities;

/// Region time zone name eg. 'America/Los_Angeles' or 'Europe/Berlin'
///
/// This will only be populated with information if the selected region
/// was populated with the automatic routing mode, otherwise empty string or nil
@property NSString *timeZoneName;


/// Convenience method to parse an API response to a GRDRegion object
/// - Parameter regionDict: the dictionary with Guardian Connect API compatible key/value pairs
- (instancetype)initWithDictionary:(NSDictionary *)regionDict;

/// Convenience method to return a GRDRegion object to set the client back to automatic routing to the nearest VPN server
+ (GRDRegion *)automaticRegion;

/// This function returns the US-East-Coast server equivalent for
/// a given region precision. Only used internally within GuardianConnect
/// and serves no other purpose
+ (GRDRegion *)failSafeRegionForRegionPrecision:(NSString *)precision;

/// Convenience method to convert timezones from the server into more useful GRDRegion instances, handy for region picker views
+ (NSArray <GRDRegion*> *)regionsFromTimezones:(NSArray *_Nullable)timezones;

/// Match GRDRegion object with full metadata for a given GRDRegion display name
/// by searching through a given array of regions incl. the nested cities array.
/// Going to return nil if a GRDRegion could not be matched for the provided
/// display name string
+ (GRDRegion *)findRegionWithDisplayName:(NSString *_Nonnull)displayName inArray:(NSArray <GRDRegion*>*_Nonnull)regions;

@end

NS_ASSUME_NONNULL_END
