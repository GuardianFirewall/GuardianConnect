//
//  GRDRegion.m
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

//experimental, should probably end up being a framework class

#import "GRDRegion.h"
#import <GuardianConnect/GRDServerManager.h>
@implementation GRDRegion

-(instancetype)initWithDictionary:(NSDictionary *)regionDict {
    self = [super init];
    if (self){
        _continent = regionDict[@"continent"]; //ie europe
        _regionName = regionDict[@"name"]; //ie eu-es
        _displayName = regionDict[@"name-pretty"]; //ie Spain
    }
    return self;
}

- (NSString *)description {
    NSString *sup = [super description];
    return [NSString stringWithFormat:@"%@: regionName: %@ displayName: %@", sup, _regionName, _displayName];
}

//overriding equality check because we MIGHT be missint contitent if we are recreated by GRDVPNHelper during credential loading.
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:self.class]){
        return false;
    }
    return (self.regionName == [object regionName] && self.displayName == [object displayName]);
}

-(void)findBestServerWithCompletion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))completion {
    [[GRDServerManager new] findBestHostInRegion:_regionName completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
        if (!error){
            if (completion){
                self.bestHost = host;
                self.bestHostLocation = hostLocation;
                completion(host, hostLocation, true);
            }
        } else {
            if (completion){
                completion(nil, nil, false);
            }
        }
    }];
}

+ (NSArray <GRDRegion*> *)regionsFromTimezones:(NSArray * _Nullable)regions {
    __block NSMutableArray *newRegions = [NSMutableArray new];
    NSArray *_theRegions = regions;
    if (_theRegions){
        _theRegions = [[NSUserDefaults standardUserDefaults] objectForKey:kGuardianAllRegions];
    }
    [_theRegions enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GRDRegion *region = [[GRDRegion alloc] initWithDictionary:obj];
        if (region){
            [newRegions addObject:region];
        }
    }];
    return [newRegions sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"displayName" ascending:true]]];
}

@end
