//
//  GRDBlocklistItem.m
//  Guardian
//
//  Created by Constantin Jacob on 08/02/24.
//  Copyright © 2024 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/GRDBlocklistItem.h>

@implementation GRDBlocklistItem

- (BOOL)isSpecialGroup {
    return FALSE;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.label forKey:@"label"];
    [aCoder encodeInteger:self.type forKey:@"type"];
    [aCoder encodeObject:self.value forKey:@"value"];
    [aCoder encodeBool:self.enabled forKey:@"enabled"];
	[aCoder encodeBool:self.smartProxyType forKey:@"smart-proxy-type"];
}

- (BOOL)isLeaf {
    return TRUE;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.identifier = [aDecoder decodeObjectForKey:@"identifier"];
        self.label = [aDecoder decodeObjectForKey:@"label"];
        self.type = GRDBlocklistTypeFromInteger([aDecoder decodeIntegerForKey:@"type"]);
        self.value = [aDecoder decodeObjectForKey:@"value"];
        self.enabled = [aDecoder decodeBoolForKey:@"enabled"];
		self.smartProxyType = [aDecoder decodeBoolForKey:@"smart-proxy-type"];
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
        self.type = GRDBlocklistTypeDNS;
        self.value = @"";
        self.enabled = NO;
		self.smartProxyType = NO;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    GRDBlocklistItem *item = [[GRDBlocklistItem allocWithZone:zone] init];
    item.identifier = self.identifier;
    item.label = self.label;
    item.type = self.type;
    item.value = self.value;
    item.enabled = self.enabled;
	item.smartProxyType = self.smartProxyType;
    return item;
}

- (void)updateWithItem:(GRDBlocklistItem *)item {
    self.label = item.label;
    self.type = item.type;
    self.value = item.value;
    self.enabled = item.enabled;
	self.smartProxyType = item.smartProxyType;
}

- (BOOL)isEqual:(id)object {
    return ([[object identifier] isEqualToString:self.identifier]);
}

- (NSString *)description {
	return [NSString stringWithFormat:@"GRDBlocklistItem: label: %@ id: %@ enabled: %@ smart-proxy-type: %@", self.label, self.identifier, self.enabled ? @"YES" : @"NO", self.smartProxyType ? @"YES" : @"NO"];
}

@end
