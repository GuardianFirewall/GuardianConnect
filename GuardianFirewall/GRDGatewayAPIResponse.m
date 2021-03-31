//
//  GRDGatewayAPIResponse.m
//  Guardian
//
//  Created by will on 4/29/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import "GRDGatewayAPIResponse.h"

@implementation GRDGatewayAPIResponse

- (NSString *)description {
    NSString *ogDesc = [super description];
    //return ogDesc;
    return [NSString stringWithFormat:@"%@ status: %lu url response: %@", ogDesc, _responseStatus, _urlResponse];
}

@end
