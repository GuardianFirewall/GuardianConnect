//
//  GRDAPIError.h
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDAPIError : NSObject

@property NSString 		*title;
@property NSString 		*message;
@property NSInteger		statusCode;

@property NSDictionary 	*apiErrorDictionary;
@property NSError 		*jsonParseError;


/// Helper method to quickly parse error messages returned from API requests
/// - Parameter jsonData: raw data object returned from a NSURLSession
- (instancetype)initWithData:(NSData *)jsonData andStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
