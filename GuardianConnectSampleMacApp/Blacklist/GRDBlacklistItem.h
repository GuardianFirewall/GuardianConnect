//
//  GRDBlacklistItem.h
//  Guardian
//
//  Created by David Skuza on 7/31/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRDBlacklistType.h"

NS_ASSUME_NONNULL_BEGIN
@interface GRDBlacklistItem : NSObject <NSCoding, NSCopying>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, assign) GRDBlacklistType type;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, assign) BOOL enabled;
- (BOOL)isLeaf;
- (void)updateWithItem:(GRDBlacklistItem *)item;

@end
NS_ASSUME_NONNULL_END
