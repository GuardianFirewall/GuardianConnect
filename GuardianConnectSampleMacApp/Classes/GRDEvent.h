//
//  GRDEvent.h
//  Guardian
//
//  Created by Kevin Bradley on 4/24/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDEvent : NSObject

@property NSString *action;
@property NSString *category;
@property NSString *host;
@property NSString *identifier;
@property NSString *message;
@property NSDate *timestamp;
@property NSString *title;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSString *)formattedTimestamp;
- (NSImage *)image;
@end

NS_ASSUME_NONNULL_END
