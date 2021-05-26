//
//  NSString+Extras.m
//  GuardianConnect
//
//  Created by Kevin Bradley on 5/23/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/NSString+Extras.h>

@implementation NSString (Extras)
- (BOOL)boolValue {
    NSArray *yesString = @[@"yes", @"true"];
    if ([yesString containsObject:self.lowercaseString]) return YES;
    NSArray *noString = @[@"no", @"false"];
    if ([noString containsObject:self.lowercaseString]) return NO;
    return NO; //by default return no... not ideal, but it'll have to do
}

- (NSString *)stringFromBool:(BOOL)boolValue {
    if (boolValue == true) return @"true";
    if (boolValue == false) return @"false";
    return nil;
}
@end
