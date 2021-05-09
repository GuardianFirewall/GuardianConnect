//
//  GRDBlacklistItem.m
//  Guardian
//
//  Created by David Skuza on 7/31/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#import "GRDBlacklistItem.h"

@implementation GRDBlacklistItem

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.label forKey:@"label"];
    [aCoder encodeInteger:self.type forKey:@"type"];
    [aCoder encodeObject:self.value forKey:@"value"];
    [aCoder encodeBool:self.enabled forKey:@"enabled"];
}

- (BOOL)isLeaf {
    return TRUE;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.label = [aDecoder decodeObjectForKey:@"label"];
        self.type = GRDBlacklistTypeFromInteger([aDecoder decodeIntegerForKey:@"type"]);
        self.value = [aDecoder decodeObjectForKey:@"value"];
        self.enabled = [aDecoder decodeBoolForKey:@"enabled"];
    }
    return self;
}

- (NSString *)title {
    return _label;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.identifier = [[NSUUID UUID] UUIDString];
        self.label = @"";
        self.type = GRDBlacklistTypeDNS;
        self.value = @"";
        self.enabled = NO;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    GRDBlacklistItem *item = [[GRDBlacklistItem allocWithZone:zone] init];
    item.identifier = self.identifier;
    item.label = self.label;
    item.type = self.type;
    item.value = self.value;
    item.enabled = self.enabled;
    return item;
}

- (void)updateWithItem:(GRDBlacklistItem *)item {
    self.label = item.label;
    self.type = item.type;
    self.value = item.value;
    self.enabled = item.enabled;
}

- (BOOL)isEqual:(id)object {
    return ([[object identifier] isEqualToString:self.identifier]);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"GRDBlacklistItem: label: %@ id: %@ enabled: %d", self.label, self.identifier, self.enabled];
}

@end
