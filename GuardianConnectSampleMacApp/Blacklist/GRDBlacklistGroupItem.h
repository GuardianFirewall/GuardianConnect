//
//  GRDBlacklistGroupItem.h
//  Guardian
//
//  Created by Kevin Bradley on 7/20/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//



#import <Foundation/Foundation.h>
#import "GRDBlacklistItem.h"
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GRDBlacklistGroupType) {
    GRDBlacklistGuardianGroupType = 1,
    GRDBlacklistCustomGroupType
};

@interface GRDBlacklistGroupItem : NSObject
@property NSString *identifier;
@property NSString *title;
@property NSString *groupDescription;
@property NSArray <GRDBlacklistItem *> * items;
@property BOOL enabled;
@property GRDBlacklistGroupType groupType;
@property BOOL allEnabled; //may be an easier way to track prior states rather than disabling/enabling all
@property BOOL allDisabled;//ditto

- (BOOL)anyDisabled;
- (BOOL)anyEnabled; //for mixed state
- (BOOL)isLeaf;
- (void)addOrUpdateItem:(GRDBlacklistItem *)item;
- (void)enableAll;
- (void)disableAll;
- (id)initWithDictionary:(NSDictionary *)blacklistGroupDictionary;
+ (NSArray <GRDBlacklistGroupItem *> *)blacklistGroupsFromJSON:(NSArray *)blacklistArray;
+ (NSArray <GRDBlacklistGroupItem *> *)dummyGroups;
+ (NSString *)randomNewIdentifier;
- (void)addItem:(GRDBlacklistItem *)item;
- (void)removeItem:(GRDBlacklistItem *)item;
- (void)saveChanges;
- (GRDBlacklistGroupItem *)updateIfNeeded:(GRDBlacklistGroupItem *)group;
- (void)selectInverse;
- (BOOL)allReallyOff;
- (BOOL)allReallyOn;
@end

NS_ASSUME_NONNULL_END
