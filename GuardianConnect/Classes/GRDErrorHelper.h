//
//  GRDErrorHelper.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 23.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString * const kGRDErrorDomainGeneral = @"GRDErrorDomainGeneral";

static NSInteger const kGRDGenericErrorCode = 0;

@interface GRDErrorHelper : NSObject

+ (NSError *)errorWithErrorCode:(NSInteger)code andErrorMessage:(NSString *)errorMessage;

@end

NS_ASSUME_NONNULL_END
