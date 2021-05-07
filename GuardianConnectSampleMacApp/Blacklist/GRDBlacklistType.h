//
//  GRDBlacklistType.h
//  Guardian
//
//  Created by David Skuza on 7/31/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#ifndef GRDBlacklistType_h
#define GRDBlacklistType_h

typedef NS_ENUM(NSInteger, GRDBlacklistType) {
    GRDBlacklistTypeDNS = 1,
    GRDBlacklistTypeIPv4,
    GRDBlacklistTypeIPv6
};

static inline GRDBlacklistType GRDBlacklistTypeFromInteger(NSInteger integer) {
    switch (integer) {
        case 1: return GRDBlacklistTypeDNS;
        case 2: return GRDBlacklistTypeIPv4;
        case 3: return GRDBlacklistTypeIPv6;
        default: return GRDBlacklistTypeDNS;
    }
}

static inline NSString* NSStringFromGRDBlacklistType(GRDBlacklistType type) {
    switch (type) {
    case GRDBlacklistTypeDNS: return @"DNS";
    case GRDBlacklistTypeIPv4: return @"IPv4";
    case GRDBlacklistTypeIPv6: return @"IPv6";
    default: return @"Unknown";
    }
    
}

#endif /* GRDBlacklistType_h */
