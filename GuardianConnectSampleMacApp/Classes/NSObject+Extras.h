//
//  NSObject+Extras.h
//  Guardian
//
//  Created by Kevin Bradley on 12/17/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Extras)

@property NSString *associatedPreference; //will allow an object to have a preference it is associated to
@property NSObject *associatedValue; //allows things like a cell switch to have a blacklist item associated to them
- (NSDictionary *)defaultLabelAttributes;
- (BOOL)proMode;
- (NSString *)documentsFolder;
@end

NS_ASSUME_NONNULL_END
