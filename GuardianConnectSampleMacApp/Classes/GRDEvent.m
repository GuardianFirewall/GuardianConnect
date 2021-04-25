//
//  GRDEvent.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDEvent.h"
#import <AppKit/AppKit.h>

@implementation GRDEvent

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self){
        _action = dict[@"action"];
        _category = dict[@"category"];
        _host = dict[@"host"];
        _identifier = dict[@"identifier"];
        _message = dict[@"message"];
        _timestamp = [NSDate dateWithTimeIntervalSince1970:[dict[@"timestamp"] integerValue]];
        _title = dict[@"title"];
    }
    return self;
}

- (NSImage *)image {
    NSImage *_image = nil;
    if ([_title isEqualToString:@"Data Tracker"]){
        _image = [NSImage imageNamed:@"dark-alert-data-tracker-sml"];
    } else if ([_title isEqualToString:@"Location Tracker"]) {
        _image = [NSImage imageNamed:@"dark-alert-location-tracker-sml"];
    } else if ([_title isEqualToString:@"Page Hijacker"]) {
        _image = [NSImage imageNamed:@"dark-alert-page-hijacker-sml"];
    } else if ([_title isEqualToString:@"Mail Tracker"]) {
        _image = [NSImage imageNamed:@"dark-alert-mail-tracker-sml"];
    }
    return _image;
}

- (NSString *)formattedTimestamp {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    return [dateFormatter stringFromDate:self.timestamp];
}

@end
