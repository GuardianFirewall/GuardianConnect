//
//  NSDate+Extras.m
//  Guardian
//
//  Created by Kevin Bradley on 10/1/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/NSDate+Extras.h>

@implementation NSDate (Extras)

- (NSDate *)dateByAddingDays:(NSInteger)days{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.day = days;
    return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
}

- (NSDate *)dateByAddingHours:(NSInteger)dHours {
    NSTimeInterval aTimeInterval = [self timeIntervalSinceReferenceDate] + D_HOUR * dHours;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];
    return newDate;
}

- (NSDate *)dateBySubtractingHours:(NSInteger)dHours {
    return [self dateByAddingHours:(dHours * -1)];
}

- (NSDate *)dateBySubtractingDays:(NSInteger)dDays {
    return [self dateByAddingDays:(dDays * -1)];
}

- (NSUInteger)daysUntil {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitDay)
                                               fromDate:[NSDate date]
                                                 toDate:self
                                                options:0];
    return [components day];
}

- (NSUInteger)daysUntilAgainstMidnight{
    // get a midnight version of ourself:
    NSDateFormatter *mdf = [NSDateFormatter new];
    [mdf setDateFormat:@"yyyy-MM-dd"];
    NSDate *midnight = [mdf dateFromString:[mdf stringFromDate:self]];
    return (int)[[NSDate date] timeIntervalSinceDate:midnight] / (60*60*24) *-1;
}

@end
