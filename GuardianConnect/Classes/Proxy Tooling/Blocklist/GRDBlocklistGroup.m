//
//  GRDBlocklistGroup.m
//  Guardian
//
//  Created by Constantin Jacob on 08/02/24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDBlocklistGroup.h>
#import <GuardianConnect/GRDVPNHelper.h>
//#import <GuardianConnect/GRDSettingsController.h>
/*
 
 {
 "title": "Facebook",
 "description": "Block Facebook and all associated domains",
 "dns_hostnames": ["hostname1.com", "hostname2.net", ...],
 ipv4_addresses: ["123.212.313.1", ...],
 ipv6_addresses: ["fe:00", ...]
 },
 
 */

@implementation GRDBlocklistGroup

+ (NSString *)guardianName { return @"GUARDIAN"; }
+ (NSString *)customName { return @"CUSTOM"; }
- (BOOL)isSpecialGroup {
    return ([self.title isEqualToString:[GRDBlocklistGroup guardianName]] || [self.title isEqualToString:[GRDBlocklistGroup customName]]);
}

- (BOOL)isLeaf {
    //if ([self isSpecialGroup]) return TRUE;
    return FALSE;
}

+ (NSArray <GRDBlocklistGroup *> *)blocklistGroupsFromJSON:(NSArray <NSDictionary *> *)blocklistArray {
    __block NSMutableArray *newArray = [NSMutableArray new];
    [blocklistArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDBlocklistGroup *item = [[GRDBlocklistGroup alloc] initWithDictionary:obj];
        item.groupType = GRDBlocklistGuardianGroupType;
        [newArray addObject:item];
        
    }];
    return newArray;
}

/**
 
 Use this is the item needs updating from the server. the only thing we could want to add from the server is more
 blocklist item entries. therefore if the input group has more items than we do, then we need to be updated!
 
 */

- (GRDBlocklistGroup *)updateIfNeeded:(GRDBlocklistGroup *)group {
    __block BOOL hasNewItem = false;
    if (group.items.count > self.items.count){
        //NSLog(@"remote group: %@ with count: %lu has more items than local group: %@ with count %lu", group,group.items.count, self, self.items.count);
        __block NSMutableArray *newItems = [self.items mutableCopy];
        
        [group.items enumerateObjectsUsingBlock:^(GRDBlocklistItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            /*
            
            comparing 'value' rather than 'identifier', the way the data exists on the server
            the individual IPs/DNS addresses dont have identifiers, we create them client side
            to do any tracking on this side re: changing data. since the users cant change this
            data, and it should ALWAYS be unique (whats the point otherwise) this SHOULD work.
             
             */
            //NSLog(@"searching for item with value: %@", obj.value);
            GRDBlocklistItem *foundItem = [[self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"value == %@", obj.value]] lastObject];
            if (!foundItem){ //no item found with that value, it should be new & unique
                //NSLog(@"no item found with value: %@", obj.value);
                hasNewItem = true;
                [newItems addObject:obj];
            }
            
        }];
        if (hasNewItem){
            self.items = newItems;
            [self saveChanges];
        }
    }
    return self;//it will always get here, and that should encompass any changes made above if necessary.
}

+ (NSArray<GRDBlocklistGroup *> *)dummyGroups {
    
    GRDBlocklistItem *fbItem = [GRDBlocklistItem new];
    fbItem.label = @"Facebook";
    fbItem.value = @"facebook.com";
    fbItem.type = GRDBlocklistTypeDNS;
    GRDBlocklistItem *googleItem = [GRDBlocklistItem new];
    googleItem.label = @"Google";
    googleItem.value = @"google.com";
    googleItem.type = GRDBlocklistTypeDNS;
    GRDBlocklistGroup *group = [GRDBlocklistGroup new];
    group.items = @[fbItem, googleItem];
    group.title = @"Social Media";
    group.groupType = GRDBlocklistGuardianGroupType;
    
    GRDBlocklistItem *customItemOne = [GRDBlocklistItem new];
    customItemOne.label = @"Item One";
    customItemOne.value = @"192.168.0.1";
    customItemOne.type = GRDBlocklistTypeIPv4;
    GRDBlocklistItem *customItemTwo = [GRDBlocklistItem new];
    customItemTwo.label = @"Item Two";
    customItemTwo.value = @"192.168.0.2";
    customItemTwo.type = GRDBlocklistTypeIPv4;
    GRDBlocklistGroup *groupTwo = [GRDBlocklistGroup new];
    groupTwo.items = @[customItemOne, customItemTwo];
    groupTwo.title = @"86";
    groupTwo.groupType = GRDBlocklistCustomGroupType;
    
    return @[group, groupTwo];
    
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeObject:self.groupDescription forKey:@"groupDescription"];
    [aCoder encodeObject:self.items forKey:@"items"];
    [aCoder encodeInteger:self.groupType forKey:@"groupType"];
    [aCoder encodeBool:self.enabled forKey:@"enabled"];
    [aCoder encodeBool:self.allEnabled forKey:@"allEnabled"];
    [aCoder encodeBool:self.allDisabled forKey:@"allDisabled"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.groupDescription = [aDecoder decodeObjectForKey:@"groupDescription"];
        self.items = [aDecoder decodeObjectForKey:@"items"];
        self.groupType = [aDecoder decodeIntegerForKey:@"groupType"];
        self.allEnabled = [aDecoder decodeBoolForKey:@"allEnabled"];
        self.allDisabled = [aDecoder decodeBoolForKey:@"allDisabled"];
        self.enabled = [aDecoder decodeBoolForKey:@"enabled"];
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    GRDBlocklistGroup *item = [[GRDBlocklistGroup allocWithZone:zone] init];
    item.title = self.title;
    item.identifier = self.identifier;
    item.groupDescription = self.groupDescription;
    item.groupType = self.groupType;
    item.items = self.items;
    item.enabled = self.enabled;
    item.allEnabled = self.allEnabled;
    item.allDisabled = self.allDisabled;
    return item;
}

- (BOOL)isEqual:(id)object {
    return ([[self identifier] isEqualToString:[object identifier]]);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"title %@ identifier: %@", self.title, self.identifier];
}

- (id)initWithDictionary:(NSDictionary *)blocklistGroupDictionary {
    
    self = [super init];
    if (self){
        [self populateFromDictionary:blocklistGroupDictionary];
    }
    return self;

}

- (void)removeItem:(GRDBlocklistItem *)item {
    NSMutableArray *items = [[self items] mutableCopy];
    [items removeObject:item];
    self.items = items;
    [self saveChanges];
}

- (void)addOrUpdateItem:(GRDBlocklistItem *)item {
    GRDBlocklistItem *foundItem = [[[self items] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", item.identifier]] lastObject];
    if (foundItem) {
        [foundItem updateWithItem:item];
        [self saveChanges];
		
    } else {
        [self addItem:item];
    }
}

- (void)addItem:(GRDBlocklistItem *)item {
    NSMutableArray *items = [[self items] mutableCopy];
    if (!items) {
        items = [NSMutableArray new];
    }
	
    [items addObject:item];
    self.items = items;
    [self saveChanges];
    
}

- (void)saveChanges {
    [GRDVPNHelper updateOrAddGroup:self];
}

- (BOOL)anyEnabled {
    GRDBlocklistItem *enabledItem = [[self enabledItems] lastObject];
    if (enabledItem) {
        return true;
    }
    return false;
}

- (NSUInteger)enabledItemsCount {
	return [[self enabledItems] count];
}

- (NSArray <GRDBlocklistItem *> *)enabledItems {
    return [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == %d", true]];
}

- (NSArray <GRDBlocklistItem *> *)disabledItems {
    return [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == %d", false]];
}

- (BOOL)allReallyOn {
    return ([self anyDisabled] == false);
}

- (BOOL)allReallyOff {
    return ([self anyEnabled] == false);
}

- (BOOL)anyDisabled {
    GRDBlocklistItem *enabledItem = [[self disabledItems] lastObject];
    if (enabledItem) {
        return true;
    }
    return false;
}

- (void)selectInverse {
    NSArray *_enabledItems = [self enabledItems];
    NSArray *_disabledItems = [self disabledItems];
    [_enabledItems enumerateObjectsUsingBlock:^(GRDBlocklistItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj setEnabled:false];
    }];
    [_disabledItems enumerateObjectsUsingBlock:^(GRDBlocklistItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
           [obj setEnabled:true];
       }];
    [self saveChanges];
}

- (void)enableAll {
    self.allEnabled = true;
    [self saveChanges];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)disableAll {
    self.allDisabled = true;
    [self saveChanges];
}

- (void)populateFromDictionary:(NSDictionary *)dict {
    _title = dict[@"title"];
    _identifier = [[NSUUID UUID] UUIDString];
    if ([[dict allKeys] containsObject:@"identifier"]) {
        _identifier = dict[@"identifier"];
    }
    __block NSMutableArray *_backingItems = [NSMutableArray new];
    
    NSArray *addresses = dict[@"dns-hostnames"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDBlocklistItem *item = [GRDBlocklistItem new];
        item.type = GRDBlocklistTypeDNS;
        item.value = obj;
        item.label = obj;
        item.group = self;
        [_backingItems addObject:item];
        
    }];
    
    addresses = dict[@"ipv4-addresses"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        GRDBlocklistItem *item = [GRDBlocklistItem new];
        item.type = GRDBlocklistTypeIPv4;
        item.value = obj;
        item.label = obj;
        item.group = self;
        [_backingItems addObject:item];
        
    }];
    
    addresses = dict[@"ipv6-addresses"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        GRDBlocklistItem *item = [GRDBlocklistItem new];
        item.type = GRDBlocklistTypeIPv6;
        item.value = obj;
        item.label = obj;
        item.group = self;
        [_backingItems addObject:item];
        
    }];
    _items = _backingItems;
    _groupDescription = dict[@"description"];
    self.allEnabled = false;  //default values
    self.allDisabled = false; //ditto
}


@end
