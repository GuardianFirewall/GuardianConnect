//
//  GRDClientRule.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 09.06.26.
//  Copyright © 2026 Sudo Security Group Inc. All rights reserved.
//

#import "GRDClientRule.h"

@implementation GRDClientRule

- (instancetype)init {
	self = [super init];
	if (self) {
		self.matchValue 		= @"";
		self.matchPort 			= @"";
		self.multihopExitRegion = @"";
	}
	
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super init];
	if (self) {
		self.matchType = [coder decodeIntegerForKey:@"match-type"];
		self.matchPort = [coder decodeObjectForKey:@"match-port"];
		self.matchValue = [coder decodeObjectForKey:@"match-value"];
		self.ruleId = [coder decodeIntegerForKey:@"rule-id"];
		self.verdict = [coder decodeIntegerForKey:@"verdict"];
		self.multihopExitRegion = [coder decodeObjectForKey:@"multihop-exit-region"];
		self.enabled = [coder decodeBoolForKey:@"enabled"];
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeInteger:self.matchType forKey:@"match-type"];
	[coder encodeObject:self.matchPort forKey:@"match-port"];
	[coder encodeObject:self.matchValue forKey:@"match-value"];
	[coder encodeInteger:self.ruleId forKey:@"rule-id"];
	[coder encodeInteger:self.verdict forKey:@"verdict"];
	[coder encodeObject:self.multihopExitRegion forKey:@"multihop-exit-region"];
	[coder encodeBool:self.enabled forKey:@"enabled"];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"match-type: %@; match-port: %@; match-value: %@; rule-id: %ld; verdict: %@; multihop-exit-region: %@", [GRDClientRule titleForMatchType:self.matchType], self.matchPort, self.matchValue, self.ruleId, [GRDClientRule titleForVerdict:self.verdict], self.multihopExitRegion];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

- (BOOL)isEqual:(id)object {
	if (![object isKindOfClass:[self class]]) {
		return NO;
	}
	
	GRDClientRule *rule = (GRDClientRule *)object;
	BOOL same = (self.matchType == rule.matchType && [self.matchPort isEqualToString:rule.matchPort] && [self.matchValue isEqualToString:rule.matchValue] && self.verdict == rule.verdict);
	return same;
}

+ (NSArray *)allMatchTypes {
	return @[@(GRDClientRuleMatchTypeFQDN), @(GRDClientRuleMatchTypeIP)];
}

+ (NSString *)titleForMatchType:(GRDClientRuleMatchType)matchType {
	if (matchType == GRDClientRuleMatchTypeFQDN) {
		return @"FQDN";
		
	} else if (matchType == GRDClientRuleMatchTypeIP) {
		return @"IP";
	}
	
	return @"UNKNOWN";
}

+ (NSString *)keyForMatchType:(GRDClientRuleMatchType)matchType {
	if (matchType == GRDClientRuleMatchTypeFQDN) {
		return @"fqdn";
		
	} else if (matchType == GRDClientRuleMatchTypeIP) {
		return @"ip";
	}
	
	return @"unknown";
}

+ (NSArray *)allVerdicts {
	return @[@(GRDClientRuleVerdictAllow), @(GRDClientRuleVerdictBlock), @(GRDClientRuleVerdictDefault)];
}

+ (NSString *)titleForVerdict:(GRDClientRuleVerdict)verdict {
	if (verdict == GRDClientRuleVerdictAllow) {
		return @"ALLOW";
		
	} else if (verdict == GRDClientRuleVerdictBlock) {
		return @"BLOCK";
		
	} else if (verdict == GRDClientRuleVerdictDefault) {
		return @"DEFAULT";
	}
	
	return @"UNKNOWN";
}

+ (NSString *)keyForVerdict:(GRDClientRuleVerdict)verdict {
	if (verdict == GRDClientRuleVerdictAllow) {
		return @"allow";
		
	} else if (verdict == GRDClientRuleVerdictBlock) {
		return @"block";
		
	} else if (verdict == GRDClientRuleVerdictDefault) {
		return @"default";
	}
	
	return @"unknown";
}

@end
