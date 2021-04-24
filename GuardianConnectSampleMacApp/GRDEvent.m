//
//  GRDEvent.m
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import "GRDEvent.h"

@implementation GRDEvent

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self){
        _action = dict[@"action"];
        _category = dict[@"category"];
        _host = dict[@"host"];
        _identifier = dict[@"identifier"];
        _message = dict[@"message"];
        _timestamp = [dict[@"timestamp"] integerValue];
        _title = dict[@"title"];
    }
    return self;
}

- (NSString *)formattedTimestamp {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    return [dateFormatter stringFromDate:self.timestamp];
}

@end
