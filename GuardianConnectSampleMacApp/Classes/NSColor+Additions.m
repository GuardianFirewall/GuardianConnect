//
//  NSColor+Additions.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#define DARK_OFF 25.0f
#define LIGHT_OFF 20.0f

#import "NSColor+Additions.h"

@implementation NSColor (Additions)

+ (BOOL)darkMode {
    NSString *interfaceStyle = [[NSUserDefaults standardUserDefaults] valueForKey:@"AppleInterfaceStyle"];
    return ([interfaceStyle isEqualToString:@"Dark"]);
}

+ (NSColor *)tagTextRedWithAlpha:(CGFloat)alpha {
    return NSColorFromRGB(0xF22E5A, alpha);
}

+ (NSColor *)tagRedWithAlpha:(CGFloat)alpha {
    return NSColorFromRGB(0xFF848C, alpha);
}

+ (NSColor *)pageHijackerPurpleSelected:(BOOL)selected {
    CGFloat alpha = 1.0;
    if ([self darkMode]){
        if (!selected) alpha = DARK_OFF;
        return NSColorFromRGB(0xC588FF, alpha);
    }
    if (!selected) alpha = 0.70;
    return NSColorFromRGB(0x7543E4, alpha);
}

+ (NSColor *)dataTrackerYellowSelected:(BOOL)selected {
    CGFloat alpha = 1.0;
    if ([self darkMode]){
        if (!selected) alpha = DARK_OFF;
        return NSColorFromRGB(0xD7BB2A, alpha);
    }
    if (!selected) alpha = LIGHT_OFF;
    return NSColorFromRGB(0xD7BB2A, alpha);
}

+ (NSColor *)locationTrackerGreenSelected:(BOOL)selected {
    CGFloat alpha = 1.0;
    if ([self darkMode]){
        if (!selected) alpha = DARK_OFF;
        return NSColorFromRGB(0x2AC4A2, alpha);
    }
    if (!selected) alpha = LIGHT_OFF;
    return NSColorFromRGB(0x2AC4A2, alpha);
}
+ (NSColor *)mailTrackerRedSelected:(BOOL)selected {
    CGFloat alpha = 1.0;
    if ([self darkMode]){
        if (!selected) alpha = DARK_OFF;
        return NSColorFromRGB(0xF22E5A, alpha);
    }
    if (!selected) alpha = LIGHT_OFF;
    return NSColorFromRGB(0xF22E5A, alpha);
}


@end
