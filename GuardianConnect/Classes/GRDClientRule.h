//
//  GRDClientRule.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 09.06.26.
//  Copyright © 2026 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GRDClientRuleMatchType) {
	GRDClientRuleMatchTypeUnknown = 0,
	GRDClientRuleMatchTypeFQDN,
	GRDClientRuleMatchTypeIP
};

typedef NS_ENUM(NSInteger, GRDClientRuleVerdict) {
	GRDClientRuleVerdictUnknown = 0,
	GRDClientRuleVerdictAllow,
	GRDClientRuleVerdictBlock,
	GRDClientRuleVerdictDefault,
	GRDClientRuleVerdictAlert
};

@interface GRDClientRule : NSObject <NSSecureCoding>

@property GRDClientRuleMatchType matchType;
@property NSString *matchPort;
@property NSString *matchValue;
@property NSInteger ruleId;
@property GRDClientRuleVerdict verdict;
@property NSString *multihopExitRegion;
@property BOOL enabled;


+ (NSArray *)allMatchTypes;

+ (NSString *)titleForMatchType:(GRDClientRuleMatchType)matchType;

+ (NSString *)keyForMatchType:(GRDClientRuleMatchType)matchType;

+ (NSArray *)allVerdicts;

+ (NSString *)titleForVerdict:(GRDClientRuleVerdict)verdict;

+ (NSString *)keyForVerdict:(GRDClientRuleVerdict)verdict;

@end

NS_ASSUME_NONNULL_END
