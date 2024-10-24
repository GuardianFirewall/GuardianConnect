//
//  GRDBlocklistItem.h
//  Guardian
//
//  Created by Constantin Jacob on 08/02/24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDBlocklistType.h>

@class GRDBlocklistGroup;

NS_ASSUME_NONNULL_BEGIN
@interface GRDBlocklistItem : NSObject <NSCoding, NSSecureCoding, NSCopying>

@property (nonatomic, copy) 	NSString *identifier;
@property (nonatomic, copy) 	NSString *label;
@property (nonatomic, assign) 	GRDBlocklistType type;
@property (nonatomic, copy) 	NSString *value;
@property (nonatomic, assign) 	BOOL enabled;
@property (nonatomic, weak) 	GRDBlocklistGroup *group;
@property (nonatomic) 			BOOL smartProxyType;

- (BOOL)isLeaf;
- (void)updateWithItem:(GRDBlocklistItem *)item;
- (NSString *)title;

@end
NS_ASSUME_NONNULL_END
