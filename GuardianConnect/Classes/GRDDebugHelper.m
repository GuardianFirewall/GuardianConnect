//
//  GRDDebugHelper.m
//  Guardian
//
//  Created by will on 5/28/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import "GRDDebugHelper.h"

@implementation GRDDebugHelper

- (instancetype)initWithTitle:(NSString *)title {
    if ([super init]) {
        self.logTitle = title;
        self.beginTime = mach_absolute_time();
        self.logTimerSet = YES;
    }
    
    return self;
}

- (void)logTimeWithMessage:(NSString *)messageStr {
#ifdef DEBUG
    if (self.logTimerSet == NO) {
        NSLog(@"[logTimeWithMessage] log timer not set, cannot log time since start (message was: '%@')", messageStr);
    }
    
    uint64_t nowTime = mach_absolute_time();
    NSLog(@"[%@] %@ (%llu ms = %llu ns)", self.logTitle, messageStr, (nowTime - self.beginTime) / 1000000, (nowTime - self.beginTime)); // convert nanoseconds to milliseconds
#endif
}

@end
