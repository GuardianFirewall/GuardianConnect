//
//  GRDRegion.h
//  Guardian
//
//  Created by Kevin Bradley on 4/25/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDRegion : NSObject

@property NSString *continent; //continent
@property NSString *regionName; //name
@property NSString *displayName; //name-pretty
@property NSString *bestHost; //defaults to nil, is populated upon get server detail completion
@property NSString *bestHostLocation; //defaults to nil, is populated upon get server detail completion
-(instancetype)initWithDictionary:(NSDictionary *)regionDict;
-(void)_findBestServerWithCompletion:(void(^)(NSString *server, NSString *serverLocation, BOOL success))block;
@end

NS_ASSUME_NONNULL_END
