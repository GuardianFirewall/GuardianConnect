//
//  GRDAlert.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 09.07.26.
//  Copyright © 2026 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDAlert : NSObject

@property (nullable, nonatomic) NSString 	*action;
@property (nullable, nonatomic) NSString 	*category;
@property (nullable, nonatomic) NSString 	*host;
@property (nullable, nonatomic) NSString 	*identifier;
@property (nullable, nonatomic) NSString 	*message;
@property (nullable, nonatomic) NSUInteger 	timestamp;
@property (nullable, nonatomic) NSDate 		*blockDate;
@property (nullable, nonatomic) NSString 	*title;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
