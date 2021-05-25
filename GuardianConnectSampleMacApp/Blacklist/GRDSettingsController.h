//
//  GRDUserDefaultsSettingsController.h
//  Guardian
//
//  Created by David Skuza on 7/23/18.
//  Copyright © 2018 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GuardianConnect/GRDNotificationMode.h>
#import "GRDBlacklistGroupItem.h"
//#import "GRDDayPassManager.h"
#import <NetworkExtension/NetworkExtension.h>
extern NSString * _Nullable const kGRDSettingsUpdatedNotification;

@class GRDBlacklistItem;

NS_ASSUME_NONNULL_BEGIN

/**
 Defines a class that utilizes NSUserDefaults to set/get various app settings.
 When a setting is changed, this class will emit a kGRDSettingsUpdatedNotification notification.
 */
@interface GRDSettingsController : NSObject

/**
 Returns a singleton instance of a GRDSettingsController.
 */
+ (instancetype)sharedInstance;

/**
 Sets a new notification mode.

 @param notificationMode The new notification mode.
 */
- (void)setNotificationMode:(GRDNotificationMode)notificationMode;

/**
 Returns the currently-set notification mode.
 */
- (GRDNotificationMode)notificationMode;

#if !TARGET_OS_OSX

/**
Update a day pass share item.

@param link The blacklist item to store.
*/

- (void)updateShareLink:(GRDDayPassShare *)link;

/**
 Stores a day pass share item.

 @param dayPassItem The blacklist item to store.
 */
- (void)addShareLink:(GRDDayPassShare *)dayPassItem;

/**
 Removes a blacklist item from the store.

 @param dayPassItem The blacklist item to remove.
 */
//- (void)removeShareLink:(GRDDayPassShare *)dayPassItem;

/**
Returns all day pass share items added by a user.
*/

- (NSArray<GRDDayPassShare *> *)dayPassItems;

#endif

/**
 Returns all blacklist items added by a user.
 */
- (NSArray<GRDBlacklistItem *> *)blacklistItems;

/**
 Returns enabled blacklist items added by a user.
 */

- (NSArray<GRDBlacklistItem *> *)enabledBlacklistItems;


/**
 Stores a new blacklist group.
 
 @param blacklistGroupItem The blacklist item to store.
 */
- (void)addBlacklistGroup:(GRDBlacklistGroupItem *)blacklistGroupItem;

/**
 Removes a blacklist group from the store.
 
 @param blacklistGroupItem The blacklist item to remove.
 */
- (void)removeBlacklistGroup:(GRDBlacklistGroupItem *)blacklistGroupItem;

/**
 Returns all blacklist items added by a user.
 */
- (NSArray<GRDBlacklistGroupItem *> *)blacklistGroups;


+ (NSString *)blacklistJavascriptString;

/**
 Returns group item based on its identifier
 
  @param groupIdentifier The identifier to locate.
 
 */

- (GRDBlacklistGroupItem *)groupWithIdentifier:(NSString *)groupIdentifier;

/**
 updates or adds a group depending on whether or not it currently exists
 
 @param group The group to add or update.
 
 */

- (void)updateOrAddGroup:(GRDBlacklistGroupItem *)group;

/**
 merges or adds a group depending on whether or not it currently exists
 
 @param group The group to add or merge.
 
 */

- (void)mergeOrAddGroup:(GRDBlacklistGroupItem *)group;

/**
 Clears out all cached / stored blocklist data, mainly for debug purposes
 */

- (void)clearBlocklistData;

#if !TARGET_OS_OSX
/**
Clears out all cached / stored day pass share link data, mainly for debug purposes
*/

- (void)clearShareLinkData;
#endif
/**
 Updates blocklist data from the server
 */

- (void)updateServerBlocklistWithItemProgress:(void (^ __nullable)(GRDBlacklistGroupItem *item))progress completion:(void (^ __nullable)(BOOL success))completion;

/// endpoint: /api/v1/blocklist/all
/// @param completion completion block returning an array of all curated blocklist items and indicating request success
- (void)requestAllBlocklistItemsWithCompletion:(void (^)(NSArray <GRDBlacklistGroupItem*> * _Nullable items, BOOL success))completion;

+ (NEProxySettings *)proxySettings;

@end

NS_ASSUME_NONNULL_END
