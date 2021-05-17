//
//  GRDDefaultsSettingsController.m
//  Guardian
//
//  Created by David Skuza on 7/23/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#import "GRDSettingsController.h"
#import <GuardianConnect/GRDHousekeepingAPI.h>
#import <GuardianConnect/GRDVPNHelper.h>

NSString *const kGRDSettingsUpdatedNotification = @"GRDSettingsUpdated";

static NSString *kGRDNotificationMode = @"GRDNotificationMode";
static NSString *kGRDBlacklistItems = @"GRDBlacklistItems";
static NSString *kGRDBlacklistGroups = @"GRDBlacklistGroups";
//static NSString *kGRDDayPassLinks = @"GRDDayPassLinks";

@interface GRDSettingsController() {
    NSMutableArray *_enableBlacklistCache;
}

@end

@implementation GRDSettingsController

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static GRDSettingsController *shared;
    dispatch_once(&onceToken, ^{
        shared = [[GRDSettingsController alloc] init];
    });
    return shared;
}

- (void)setNotificationMode:(GRDNotificationMode)notificationMode {
    [[NSUserDefaults standardUserDefaults] setInteger:notificationMode forKey:kGRDNotificationMode];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSettingsUpdatedNotification object:nil];
}

- (GRDNotificationMode)notificationMode {
    NSInteger currentMode = [[NSUserDefaults standardUserDefaults] integerForKey:kGRDNotificationMode];
    return GRDNotificationModeFromInteger(currentMode);
}
/*
- (void)addShareLink:(GRDDayPassShare *)dayPassItem {
    if (!dayPassItem) { return; }
    
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDDayPassLinks];
    NSMutableArray<NSData *> *daypassLinks = [NSMutableArray arrayWithArray:storedItems];
    if (!daypassLinks.count) {
        daypassLinks = [NSMutableArray array];
    }
    [daypassLinks insertObject:[NSKeyedArchiver archivedDataWithRootObject:dayPassItem] atIndex:0];
    [[NSUserDefaults standardUserDefaults] setValue:daypassLinks forKey:kGRDDayPassLinks];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDDayPassCountChanged object:nil];
     
}

- (void)removeShareLink:(GRDDayPassShare *)dayPassItem {
    if (!dayPassItem) { return; }
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDDayPassLinks];
    NSMutableArray<NSData *> *daypassLinks = [NSMutableArray arrayWithArray:storedItems];
    if (daypassLinks.count) {
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:dayPassItem];
        [daypassLinks removeObject:itemData];
        [[NSUserDefaults standardUserDefaults] setValue:daypassLinks forKey:kGRDDayPassLinks];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDDayPassCountChanged object:nil];
}

- (NSArray<GRDDayPassShare *> *)dayPassItems {
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDDayPassLinks];
    NSMutableArray<GRDDayPassShare*> *daypassLinks = [NSMutableArray array];
    for (NSData *item in items) {
        GRDDayPassShare *dayPassItem = [NSKeyedUnarchiver unarchiveObjectWithData:item];
        [daypassLinks addObject:dayPassItem];
    }
    return daypassLinks;
}
 
 - (GRDDayPassShare *)shareWithDPRT:(NSString *)dprt {
     return [[[self dayPassItems] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"dprt == %@", dprt]] lastObject];
 }

 - (void)updateShareLink:(GRDDayPassShare *)link {
     //NSLog(@"updatingShareLink: %@", link);
     NSMutableArray *modifiedArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kGRDDayPassLinks] mutableCopy];
     GRDDayPassShare *oldLink = [self shareWithDPRT:link.dprt];
     //NSLog(@"oldLink: %@", oldLink);
     NSInteger objectIndex = [[self dayPassItems]indexOfObject:oldLink];
     if (objectIndex == NSNotFound){
         //NSLog(@"[DEBUG] group with id not found: %@", group.identifier);
         [self addShareLink:link];
         return;
     } else {
         //NSLog(@"[DEBUG] day pass item with id found at index: %lu", objectIndex);
         NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject: link];
         [modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
     }
     [[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDDayPassLinks];
     [[NSNotificationCenter defaultCenter] postNotificationName:kGRDDayPassCountChanged object:nil];
 }
 
 - (void)clearShareLinkData {
     [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDDayPassLinks];
 }

 
*/

+ (NSString *)blacklistJavascriptString {

    NSArray <GRDBlacklistItem *> *blacklist = [[GRDSettingsController sharedInstance] enabledBlacklistItems];
    __block NSMutableString *matchString = [[NSMutableString alloc] initWithString:@"if ("]; //start the if statement
    [blacklist enumerateObjectsUsingBlock:^(GRDBlacklistItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSString *formattedString = nil;
        switch (obj.type) {
            case GRDBlacklistTypeDNS:{
                formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\") || ", obj.value]; //keep addding || until we know we are the last item
                if (idx  == blacklist.count - 1){
                    formattedString = [NSString stringWithFormat:@"dnsDomainIs(host, \"%@\")) return \"PROXY 255.255.255.0:3421\";", obj.value]; //last item, wrap it up
                }
            }
                break;
                
            case GRDBlacklistTypeIPv4: {//(host == "216.66.21.35")
            case GRDBlacklistTypeIPv6:
                formattedString = [NSString stringWithFormat:@"(host == \"%@\") || ", obj.value]; //keep addding || until we know we are the last item
                if (idx  == blacklist.count - 1){
                    formattedString = [NSString stringWithFormat:@"(host == \"%@\")) return \"PROXY 255.255.255.0:3421\";", obj.value]; //last item, wrap it up
                }
            }
                break;
                
            default:
                break;
        }
        
        [matchString appendString:formattedString]; //put it all together
    }];
    
    if (blacklist.count > 0){ //only add these changes if the blacklist has any enabled items.
        return [NSString stringWithFormat:@"function FindProxyForURL(url, host) { %@ return \"DIRECT\";}", matchString];
    }

    return nil;
}

+ (NEProxySettings *)proxySettings {
    NEProxySettings *proxSettings = [NEProxySettings new];
    NSString *blacklistJS = [GRDSettingsController blacklistJavascriptString];
    if (blacklistJS != nil){ //only add these changes if the blacklist has any enabled items.
        proxSettings.autoProxyConfigurationEnabled = YES;
        proxSettings.proxyAutoConfigurationJavaScript = blacklistJS;
    }
    return proxSettings;
}
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (NSArray<GRDBlacklistItem *> *)blacklistItems {
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistItems];
    NSMutableArray<GRDBlacklistItem*> *blacklistItems = [NSMutableArray array];
    for (NSData *item in items) {

        GRDBlacklistItem *blacklistItem = [NSKeyedUnarchiver unarchiveObjectWithData:item];
        [blacklistItems addObject:blacklistItem];
    }
    return blacklistItems;
}


- (NSArray<GRDBlacklistItem *> *)enabledBlacklistItems {
    
    if (_enableBlacklistCache){
        return _enableBlacklistCache;
    }
    __block NSMutableArray *enabledItems = [NSMutableArray new];
    NSArray <GRDBlacklistGroupItem*> *enabledGroups = [[self blacklistGroups] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"allDisabled == false"]];
 
    [enabledGroups enumerateObjectsUsingBlock:^(GRDBlacklistGroupItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj allEnabled]){
            [enabledItems addObjectsFromArray:obj.items];
        } else { //check individually
            NSArray *enabled = [[obj items] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == true"]];
            [enabledItems addObjectsFromArray:enabled];
        }
        
    }];
    _enableBlacklistCache = enabledItems;
    return enabledItems;
}

- (void)addBlacklistGroup:(GRDBlacklistGroupItem *)blacklistGroupItem {
    if (!blacklistGroupItem) { return; }
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistGroups];
    NSMutableArray<NSData *> *blacklistGroups = [NSMutableArray arrayWithArray:storedItems];
    if (!blacklistGroups.count) {
        blacklistGroups = [NSMutableArray array];
    }

    [blacklistGroups insertObject:[NSKeyedArchiver archivedDataWithRootObject:blacklistGroupItem] atIndex:0];
    [[NSUserDefaults standardUserDefaults] setValue:blacklistGroups forKey:kGRDBlacklistGroups];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSettingsUpdatedNotification object:nil];
    _enableBlacklistCache = nil;
}

- (void)removeBlacklistGroup:(GRDBlacklistGroupItem *)blacklistGroupItem {
    if (!blacklistGroupItem) { return; }
    NSArray<NSData *> *storedItems = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistGroups];
    NSMutableArray<NSData *> *blacklistGroups = [NSMutableArray arrayWithArray:storedItems];
    if (blacklistGroups.count) {
        NSData *itemData = [NSKeyedArchiver archivedDataWithRootObject:blacklistGroupItem];
        [blacklistGroups removeObject:itemData];
        [[NSUserDefaults standardUserDefaults] setValue:blacklistGroups forKey:kGRDBlacklistGroups];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSettingsUpdatedNotification object:nil];
    }
    _enableBlacklistCache = nil;
}

- (NSArray<GRDBlacklistGroupItem *> *)blacklistGroups {
    NSArray<NSData *> *items = [[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistGroups];
    NSMutableArray<GRDBlacklistGroupItem*> *blacklistGroups = [NSMutableArray array];
    for (NSData *item in items) {
        GRDBlacklistGroupItem *blacklistGroup = [NSKeyedUnarchiver unarchiveObjectWithData:item];
        [blacklistGroups addObject:blacklistGroup];
    }
    return blacklistGroups;
}


- (void)mergeOrAddGroup:(GRDBlacklistGroupItem *)group {
    
    NSMutableArray *modifiedArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistGroups] mutableCopy];
    GRDBlacklistGroupItem *oldGroup = [self groupWithIdentifier:group.identifier];
    NSInteger objectIndex = [[self blacklistGroups]indexOfObject:oldGroup];
    if (objectIndex == NSNotFound){
        //NSLog(@"[DEBUG] group with id not found: %@", group.identifier);
        [self addBlacklistGroup:group];
        return;
    } else {
        //NSLog(@"[DEBUG] group with id found at index: %lu", objectIndex);
        GRDBlacklistGroupItem *mergedGroup = [oldGroup updateIfNeeded:group];
        NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject: mergedGroup];
        [modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
    }
    [[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDBlacklistGroups];
    [[NSUserDefaults standardUserDefaults] synchronize];
    //[[NSNotificationCenter defaultCenter] postNotificationName:kGRDSettingsUpdatedNotification object:nil];
    _enableBlacklistCache = nil;
}



- (void)updateOrAddGroup:(GRDBlacklistGroupItem *)group {
    NSMutableArray *modifiedArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kGRDBlacklistGroups] mutableCopy];
    GRDBlacklistGroupItem *oldGroup = [self groupWithIdentifier:group.identifier];
    NSInteger objectIndex = [[self blacklistGroups]indexOfObject:oldGroup];
    if (objectIndex == NSNotFound){
        //NSLog(@"[DEBUG] group with id not found: %@", group.identifier);
        [self addBlacklistGroup:group];
        return;
    } else {
        //NSLog(@"[DEBUG] group with id found at index: %lu", objectIndex);
        NSData *newGroup = [NSKeyedArchiver archivedDataWithRootObject: group];
        [modifiedArray replaceObjectAtIndex:objectIndex withObject:newGroup];
    }
    [[NSUserDefaults standardUserDefaults] setValue:modifiedArray forKey:kGRDBlacklistGroups];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDSettingsUpdatedNotification object:nil];
    _enableBlacklistCache = nil;
    
}

#pragma clang diagnostic pop

- (GRDBlacklistGroupItem *)groupWithIdentifier:(NSString *)groupIdentifier {
    NSArray <GRDBlacklistGroupItem*> *groups = [self blacklistGroups];
    return [[groups filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", groupIdentifier]] lastObject];
}


- (void)clearBlocklistData {
    _enableBlacklistCache = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDBlacklistGroups];
}

- (void)requestAllBlocklistItemsWithCompletion:(void (^)(NSArray <GRDBlacklistGroupItem*> * _Nullable items, BOOL success))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://housekeeping.sudosecuritygroup.com/api/v1/blocklist/all-items"]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Failed to get all blocklist items: %@", error);
            if (completion) completion(nil, NO);
        }
        
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode == 500) {
            NSLog(@"[requestAllBlocklistItems] Internal server error");
            if (completion) completion(nil, NO);
            return;
            
        } else if (statusCode == 204) {
            NSLog(@"No blocklist items available. Display empty UI");
            if (completion) completion(@[], YES);
            return;
            
        } else if (statusCode == 200) {
            NSArray *blocklistItems = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray <GRDBlacklistGroupItem*> *returnItems = [GRDBlacklistGroupItem blacklistGroupsFromJSON:blocklistItems];
            
            if (completion) completion(returnItems, YES);
            return;
            
        } else {
            NSLog(@"Unknown server response: %ld", statusCode);
            if (completion) completion(nil, NO);
        }
    }];
    [task resume];
}


- (void)updateServerBlocklistWithItemProgress:(void (^ __nullable)(GRDBlacklistGroupItem *item))progress completion:(void (^ __nullable)(BOOL success))block {
    if (![GRDVPNHelper proMode]){
        if (block){
            block(FALSE);
        }
        return;
    }
    [self requestAllBlocklistItemsWithCompletion:^(NSArray<GRDBlacklistGroupItem *> * _Nullable allBlocklistItems, BOOL success) {
        
        if (success){
            //NSLog(@"allBlocklistItems: %@", allBlocklistItems);
            [allBlocklistItems enumerateObjectsUsingBlock:^(GRDBlacklistGroupItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self mergeOrAddGroup:obj];
                if (progress){
                    progress(obj);
                }
                if (idx == allBlocklistItems.count-1){
                        if (block){
                            block(TRUE);
                        }
                }
            }];
        } else {
            if (block){
                block(FALSE);
            }
        }
    }];
}


@end
