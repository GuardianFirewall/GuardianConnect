//
//  GRDBlocklistType.h
//  Guardian
//
//  Created by Constantin Jacob on 08/02/24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#ifndef GRDBlocklistType_h
#define GRDBlocklistType_h

typedef NS_ENUM(NSInteger, GRDBlocklistType) {
    GRDBlocklistTypeDNS = 1,
    GRDBlocklistTypeIPv4,
    GRDBlocklistTypeIPv6
};

static inline GRDBlocklistType GRDBlocklistTypeFromInteger(NSInteger integer) {
    switch (integer) {
        case 1: return GRDBlocklistTypeDNS;
        case 2: return GRDBlocklistTypeIPv4;
        case 3: return GRDBlocklistTypeIPv6;
        default: return GRDBlocklistTypeDNS;
    }
}

static inline NSString* NSStringFromGRDBlocklistType(GRDBlocklistType type) {
    switch (type) {
    case GRDBlocklistTypeDNS: return @"DNS";
    case GRDBlocklistTypeIPv4: return @"IPv4";
    case GRDBlocklistTypeIPv6: return @"IPv6";
    default: return @"Unknown";
    }
    
}

#endif /* GRDBlocklistType_h */
