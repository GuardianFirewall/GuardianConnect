//
//  NSColor+Additions.h
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


#define NSColorFromRGB(rgbValue, alp) [NSColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:alp]

@interface NSColor (Additions)

+ (NSColor *)pageHijackerPurpleSelected:(BOOL)selected;
+ (NSColor *)dataTrackerYellowSelected:(BOOL)selected;
+ (NSColor *)locationTrackerGreenSelected:(BOOL)selected;
+ (NSColor *)mailTrackerRedSelected:(BOOL)selected;
+ (BOOL)darkMode;

@end

NS_ASSUME_NONNULL_END
