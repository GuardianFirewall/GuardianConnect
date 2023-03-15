//
//  GRDTunnelManager.h
//  Guardian
//
//  Created by Kevin Bradley on 2/3/21.
//  Copyright © 2021 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

NS_ASSUME_NONNULL_BEGIN

@interface GRDTunnelManager : NSObject

@property BOOL blocklistEnabled; //defaults to false
@property NETunnelProviderManager * _Nullable tunnelProviderManager;

/// If set this callback handler will be called from both +sharedManager as well as + loadTunnelManagerFromPreferences: and will allow you to be notified immediately
///
/// If set immediately after the first call to [GRDVPNHelper sharedInstance] this is effectively racing the NetworkExtensions framework to be set before the [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:] returns and could potentially be dangerous or lead to instability and unpredictable behaviour of the app.
/// Please proceed with caution and test thoroughly!
@property (nonatomic, copy, nullable) void (^tunnelLoadedCallback)(NEVPNStatus connectionStatus, NSError * _Nullable error);

+ (id)sharedManager;

+ (BOOL)tunnelConnected;

- (void)ensureTunnelManagerWithCompletion:(void (^_Nullable)(NETunnelProviderManager *_Nullable tunnelManager, NSString *_Nullable errorMessage))completion;

- (void)loadTunnelManagerFromPreferences:(void (^_Nullable)(NETunnelProviderManager * __nullable manager, NSError * __nullable errorMessage))completion;

/// Convenience method to quickly delete the current tunnel manager out of the iOS preferences
- (void)removeTunnelFromPreferences:(void (^_Nullable)(NSError *_Nullable error))completion;

/// Used to determine whether or not the NETunnelManager has already been configured on this device
/// Used to prevent the client to show an awkward modal system alert asking to install the personal VPN configuration without any context
+ (void)tunnelConfiguredWithCompletion:(void(^)(BOOL configured))completion;

/// Returns the tunnel manager's current connection status as a NEVPNStatus
- (NEVPNStatus)currentTunnelProviderState;

/// Returns the tunnel manager's current connection status as a NEVPNStatus
///
/// In the case of  no tunnel manager being installed yet, eg. after first installation on a device, this function will return NEVPNStatusInvalid & nil in the completion block
/// - Parameter completion: completion block containing the connection status as well as an error message in case of a failure to load the array of tunnel managers
- (void)currentTunnelProviderStateWithCompletion:(void (^_Nullable)(NEVPNStatus status, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
