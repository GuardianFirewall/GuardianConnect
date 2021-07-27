//
//  NSObject+Dictionary.m
//  GuardianConnect
//
//  Created by Kevin Bradley on 7/9/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <GuardianConnect/NSObject+Dictionary.h>
#import <objc/runtime.h>

@implementation NSDictionary (String)

- (NSString *)JSONRepresentation {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end

@implementation NSObject (Dictionary)

- (NSArray *)propertiesForClass:(Class)clazz {
    u_int count;
    objc_property_t* properties = class_copyPropertyList(clazz, &count);
    NSMutableArray* propArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++)
    {
        const char* propertyName = property_getName(properties[i]);
        NSString *propName = [NSString  stringWithCString:propertyName encoding:NSUTF8StringEncoding];
        [propArray addObject:propName];
    }
    free(properties);
    return propArray;
}

- (NSArray *)properties {
    u_int count;
    objc_property_t* properties = class_copyPropertyList(self.class, &count);
    NSMutableArray* propArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++)
    {
        const char* propertyName = property_getName(properties[i]);
        NSString *propName = [NSString  stringWithCString:propertyName encoding:NSUTF8StringEncoding];
        [propArray addObject:propName];
    }
    free(properties);
    return propArray;
}

- (id)valueForUndefinedKey:(NSString *)key {
    GRDLog(@"in value for undefined key: %@", key);
    return nil;
}

//we'll never care about an items delegate details when saving a dict rep, this prevents an inifinite loop/crash on some classes.
- (NSDictionary *)dictionaryRepresentation {
    return [self dictionaryRepresentationExcludingProperties:@[@"delegate"]];
}

/*
 
 This extremely useful function will take the current class (rather than NSObject), convert all of its properties
 and convert them into NSDictionary representations that /should/ be JSON friendly. This is mainly used to change SKProducts
 into a useful dictionary to feed to the API for partner product ID's.
 
 */

- (NSDictionary *)dictionaryRepresentationExcludingProperties:(NSArray *)excluding {
    __block NSMutableDictionary *dict = [NSMutableDictionary new];
    Class cls = NSClassFromString([self valueForKey:@"className"]); //this is how we hone in our the properties /just/ for our specific class rather than NSObject's properties.
    NSArray *props = [self propertiesForClass:cls];
    //GRDLog(@"props: %@ for %@", props, self);
    [props enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        //get the value of the particular property
        id val = [self valueForKey:obj];
        if ([val isKindOfClass:NSString.class] || [val isKindOfClass:NSNumber.class]) { //add numbers and strings as is
            [dict setValue:val forKey:obj];
        } else { //not a string or a number
            if ([val isKindOfClass:NSArray.class]) {
                //GRDLog(@"processing: %@ for %@", obj, [self valueForKey:@"className"]);
                __block NSMutableArray *_newArray = [NSMutableArray new]; //new array will hold the dictionary reps of each item inside said array.
                [val enumerateObjectsUsingBlock:^(id  _Nonnull arrayObj, NSUInteger arrayIdx, BOOL * _Nonnull arrayStop) {
                    [_newArray addObject:[arrayObj dictionaryRepresentation]]; //call ourselves again, but with the current subarray object.
                }];
                [dict setValue:_newArray forKey:obj];
            } else if ([val isKindOfClass:NSDictionary.class]) {
                [dict setValue:val forKey:obj];
            } else { //not an NSString, NSNumber of NSArray, try setting its dict rep for the key.
                //NSString* class = NSStringFromClass(self.class);
                if (val && ![[self valueForKey:@"className"] isEqualToString:@"NSObject"] && !([excluding containsObject:obj])) {
                    //GRDLog(@"processing: %@ for %@", val, obj);
                    [dict setValue:[val dictionaryRepresentation] forKey:obj];
                }
            }
        }
    }];
    return dict;
}
@end
