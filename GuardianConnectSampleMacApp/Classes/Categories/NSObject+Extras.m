//
//  NSObject+Extras.m
//  Guardian
//
//  Created by Kevin Bradley on 12/17/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

//helps navigate our UI when its hard to determine how to present a new view controller easily.

#import "NSObject+Extras.h"
#import <objc/runtime.h>
#import <GuardianConnect/GRDVPNHelper.h>
#import <AppKit/AppKit.h>

@implementation NSObject (Extras)

#ifdef DEBUG

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
    Class sup = [self superclass];
    while (sup != nil){
        NSArray *a = [sup propertiesForClass:sup];
        [propArray addObjectsFromArray:a];
        sup = [sup superclass];
    }
    return propArray;
}

- (NSArray *)ivarsForClass:(Class)clazz {
    
    u_int count;
    Ivar* ivars = class_copyIvarList(clazz, &count);
    NSMutableArray* ivarArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++)
    {
        const char* ivarName = ivar_getName(ivars[i]);
        [ivarArray addObject:[NSString  stringWithCString:ivarName encoding:NSUTF8StringEncoding]];
    }
    free(ivars);
    return ivarArray;
}

-(NSArray *)ivars
{
    Class clazz = [self class];
    u_int count;
    Ivar* ivars = class_copyIvarList(clazz, &count);
    NSMutableArray* ivarArray = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count ; i++)
    {
        const char* ivarName = ivar_getName(ivars[i]);
        [ivarArray addObject:[NSString  stringWithCString:ivarName encoding:NSUTF8StringEncoding]];
    }
    free(ivars);
    Class sup = [self superclass];
    while (sup != nil){
        NSArray *a = [sup ivarsForClass:sup];
        [ivarArray addObjectsFromArray:a];
        sup = [sup superclass];
    }
    return ivarArray;
}

#endif

- (NSDictionary *)defaultLabelAttributes {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineHeightMultiple = 1.26;
    return @{NSKernAttributeName:@(-0.4), NSParagraphStyleAttributeName: paragraphStyle};
}

- (BOOL)proMode {
    return ([GRDVPNHelper proMode]);
}

- (NSObject *)associatedValue {
    return objc_getAssociatedObject(self, @selector(associatedValue));
}

- (void)setAssociatedValue:(NSObject *)val {
    objc_setAssociatedObject(self, @selector(associatedValue), val, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)associatedPreference {
       return objc_getAssociatedObject(self, @selector(associatedPreference));
}
- (void)setAssociatedPreference:(NSString *)pref {
    objc_setAssociatedObject(self, @selector(associatedPreference), pref, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)documentsFolder {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

@end
