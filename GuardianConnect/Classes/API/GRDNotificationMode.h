//
//  GRDNotificationMode.h
//  Guardian
//
//  Created by David Skuza on 7/23/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#ifndef GRDNotificationMode_h
#define GRDNotificationMode_h

typedef NS_ENUM(NSInteger, GRDNotificationMode) {
    GRDNotificationModeInstant = 1,
    GRDNotificationModeDaily
};

static inline GRDNotificationMode GRDNotificationModeFromInteger(NSInteger integer) {
    switch (integer) {
        case 1: return GRDNotificationModeInstant;
        case 2: return GRDNotificationModeDaily;
        default: return GRDNotificationModeInstant;
    }
}

#endif /* GRDNotificationMode_h */
