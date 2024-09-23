//
//  GRDBlocklistGroup.h
//  Guardian
//
//  Created by Constantin Jacob on 08/02/24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDBlocklistItem.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GRDBlocklistGroupType) {
    GRDBlocklistGuardianGroupType = 1,
    GRDBlocklistCustomGroupType
};

@interface GRDBlocklistGroup : NSObject
@property NSString *identifier;
@property NSString *title;
@property NSString *groupDescription;
@property NSArray <GRDBlocklistItem *> *items;
@property BOOL enabled;
@property GRDBlocklistGroupType groupType;
@property BOOL allEnabled; //may be an easier way to track prior states rather than disabling/enabling all
@property BOOL allDisabled;//ditto

+ (NSString *)guardianName;
+ (NSString *)customName;

- (BOOL)anyDisabled;
- (BOOL)anyEnabled; //for mixed state
- (NSUInteger)enabledItemsCount;
- (NSArray <GRDBlocklistItem *> *)enabledItems;
- (NSArray <GRDBlocklistItem *> *)disabledItems;
- (BOOL)isLeaf;
- (void)addOrUpdateItem:(GRDBlocklistItem *)item;
- (void)enableAll;
- (void)disableAll;
- (id)initWithDictionary:(NSDictionary *)blocklistGroupDictionary;
+ (NSArray <GRDBlocklistGroup *> *)blocklistGroupsFromJSON:(NSArray *)blocklistArray;
+ (NSArray <GRDBlocklistGroup *> *)dummyGroups;
- (void)addItem:(GRDBlocklistItem *)item;
- (void)removeItem:(GRDBlocklistItem *)item;
- (void)saveChanges;
- (GRDBlocklistGroup *)updateIfNeeded:(GRDBlocklistGroup *)group;
- (void)selectInverse;
- (BOOL)allReallyOff;
- (BOOL)allReallyOn;
@end

NS_ASSUME_NONNULL_END
