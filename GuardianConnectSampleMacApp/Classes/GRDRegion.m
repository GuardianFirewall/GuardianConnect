//
//  GRDRegion.m
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

//experimental, should probably end up being a framework class

#import "GRDRegion.h"
#import <GuardianConnect/GuardianConnectMac.h>
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

-(void)_findBestServerWithCompletion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))block {
    [[GRDServerManager new] findBestHostInRegion:_regionName completion:^(NSString * _Nonnull host, NSString * _Nonnull hostLocation, NSString * _Nonnull error) {
        if (!error){
            if (block){
                block(host, hostLocation, true);
                _bestHost = host;
                _bestHostLocation = hostLocation;
            }
        } else {
            if (block){
                block(nil, nil, false);
            }
        }
    }];
}

@end
