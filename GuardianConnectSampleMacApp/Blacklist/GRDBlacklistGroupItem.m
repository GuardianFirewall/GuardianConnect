//
//  GRDBlacklistGroupItem.m
//  Guardian
//
//  Created by Kevin Bradley on 7/20/20.
//  Copyright © 2020 Sudo Security Group Inc. All rights reserved.
//

#import "GRDBlacklistGroupItem.h"
#import "GRDSettingsController.h"
/*
 
 {
 "title": "Facebook",
 "description": "Block Facebook and all associated domains",
 "dns_hostnames": ["hostname1.com", "hostname2.net", ...],
 ipv4_addresses: ["123.212.313.1", ...],
 ipv6_addresses: ["fe:00", ...]
 },
 
 */

@implementation GRDBlacklistGroupItem

- (BOOL)isLeaf {
    return TRUE;
}

+ (NSString *)randomNewIdentifier {
    return [[NSUUID UUID] UUIDString];
}

+ (NSArray <GRDBlacklistGroupItem *> *)blacklistGroupsFromJSON:(NSArray <NSDictionary *> *)blacklistArray {
    __block NSMutableArray *newArray = [NSMutableArray new];
    [blacklistArray enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDBlacklistGroupItem *item = [[GRDBlacklistGroupItem alloc] initWithDictionary:obj];
        item.groupType = GRDBlacklistGuardianGroupType;
        [newArray addObject:item];
        
    }];
    return newArray;
}

/**
 
 Use this is the item needs updating from the server. the only thing we could want to add from the server is more
 blacklist item entries. therefore if the input group has more items than we do, then we need to be updated!
 
 */

- (GRDBlacklistGroupItem *)updateIfNeeded:(GRDBlacklistGroupItem *)group {
    __block BOOL hasNewItem = false;
    if (group.items.count > self.items.count){
        //NSLog(@"remote group: %@ with count: %lu has more items than local group: %@ with count %lu", group,group.items.count, self, self.items.count);
        __block NSMutableArray *newItems = [self.items mutableCopy];
        
        [group.items enumerateObjectsUsingBlock:^(GRDBlacklistItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            /*
            
            comparing 'value' rather than 'identifier', the way the data exists on the server
            the individual IPs/DNS addresses dont have identifiers, we create them client side
            to do any tracking on this side re: changing data. since the users cant change this
            data, and it should ALWAYS be unique (whats the point otherwise) this SHOULD work.
             
             */
            //NSLog(@"searching for item with value: %@", obj.value);
            GRDBlacklistItem *foundItem = [[self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"value == %@", obj.value]] lastObject];
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

+ (NSArray<GRDBlacklistGroupItem *> *)dummyGroups {
    
    GRDBlacklistItem *fbItem = [GRDBlacklistItem new];
    fbItem.label = @"Facebook";
    fbItem.value = @"facebook.com";
    fbItem.type = GRDBlacklistTypeDNS;
    GRDBlacklistItem *googleItem = [GRDBlacklistItem new];
    googleItem.label = @"Google";
    googleItem.value = @"google.com";
    googleItem.type = GRDBlacklistTypeDNS;
    GRDBlacklistGroupItem *group = [GRDBlacklistGroupItem new];
    group.items = @[fbItem, googleItem];
    group.title = @"Social Media";
    group.groupType = GRDBlacklistGuardianGroupType;
    
    GRDBlacklistItem *customItemOne = [GRDBlacklistItem new];
    customItemOne.label = @"Item One";
    customItemOne.value = @"192.168.0.1";
    customItemOne.type = GRDBlacklistTypeIPv4;
    GRDBlacklistItem *customItemTwo = [GRDBlacklistItem new];
    customItemTwo.label = @"Item Two";
    customItemTwo.value = @"192.168.0.2";
    customItemTwo.type = GRDBlacklistTypeIPv4;
    GRDBlacklistGroupItem *groupTwo = [GRDBlacklistGroupItem new];
    groupTwo.items = @[customItemOne, customItemTwo];
    groupTwo.title = @"86";
    groupTwo.groupType = GRDBlacklistCustomGroupType;
    
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
    GRDBlacklistGroupItem *item = [[GRDBlacklistGroupItem allocWithZone:zone] init];
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

- (id)initWithDictionary:(NSDictionary *)blacklistGroupDictionary {
    
    self = [super init];
    if (self){
        [self populateFromDictionary:blacklistGroupDictionary];
    }
    return self;

}

- (void)removeItem:(GRDBlacklistItem *)item {
    NSMutableArray *items = [[self items] mutableCopy];
    [items removeObject:item];
    self.items = items;
    [self saveChanges];
}

- (void)addOrUpdateItem:(GRDBlacklistItem *)item {
    
    NSLog(@"[DEBUG]: item id: %@ items: %@", item, self.items);
    
    GRDBlacklistItem *foundItem = [[[self items] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", item.identifier]] lastObject];
    if (foundItem){
        NSLog(@"[DEBUG]: found item to update %@", foundItem);
        [foundItem updateWithItem:item];
        [self saveChanges];
    } else {
        [self addItem:item];
    }
    
}

- (void)addItem:(GRDBlacklistItem *)item {
    
    NSMutableArray *items = [[self items] mutableCopy];
    if (!items){
        items = [NSMutableArray new];
    }
    [items addObject:item];
    self.items = items;
    [self saveChanges];
    
}

- (void)saveChanges {
    
    GRDSettingsController *settingsController = [GRDSettingsController sharedInstance];
    [settingsController updateOrAddGroup:self];
}

- (void)enableAll {
    
    self.allEnabled = true;
    [self saveChanges];
  
}

- (instancetype)init {
    self = [super init];
    if (self){
        _identifier = [GRDBlacklistGroupItem randomNewIdentifier];
    }
    return self;
}

- (void)disableAll {
    
    self.allDisabled = true;
    [self saveChanges];
   
}

- (void)populateFromDictionary:(NSDictionary *)dict {
    _title = dict[@"title"];
    _identifier = [GRDBlacklistGroupItem randomNewIdentifier];
    if ([[dict allKeys] containsObject:@"identifier"]){
        _identifier = dict[@"identifier"];
    }
    __block NSMutableArray *_backingItems = [NSMutableArray new];
    
    NSArray *addresses = dict[@"dns-hostnames"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
       
        GRDBlacklistItem *item = [GRDBlacklistItem new];
        item.type = GRDBlacklistTypeDNS;
        item.value = obj;
        item.label = obj;
        
        [_backingItems addObject:item];
        
    }];
    
    addresses = dict[@"ipv4-addresses"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        GRDBlacklistItem *item = [GRDBlacklistItem new];
        item.type = GRDBlacklistTypeIPv4;
        item.value = obj;
        item.label = obj;
        
        [_backingItems addObject:item];
        
    }];
    
    addresses = dict[@"ipv6-addresses"];
    [addresses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        GRDBlacklistItem *item = [GRDBlacklistItem new];
        item.type = GRDBlacklistTypeIPv6;
        item.value = obj;
        item.label = obj;
        
        [_backingItems addObject:item];
        
    }];
    _items = _backingItems;
    _groupDescription = dict[@"description"];
    self.allEnabled = false;  //default values
    self.allDisabled = false; //ditto
}


@end
