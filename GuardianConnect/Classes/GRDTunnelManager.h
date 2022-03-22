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

+ (id)sharedManager;

+ (BOOL)tunnelConnected;

- (void)ensureTunnelManagerWithCompletion:(void (^_Nullable)(NETunnelProviderManager *_Nullable tunnelManager, NSString *_Nullable errorMessage))completion;

- (void)loadTunnelManagerFromPreferences:(void (^_Nullable)(NETunnelProviderManager * __nullable manager, NSString * __nullable errorMessage))completion;

/// Used to determine whether or not the NETunnelManager has already been configured on this device
/// Used to prevent the client to show an awkward modal system alert asking to install the personal VPN configuration without any context
+ (void)tunnelConfiguredWithCompletion:(void(^)(BOOL configured))completion;

- (NEVPNStatus)currentTunnelProviderState;
- (BOOL)toggleTunnelProviderState;
- (BOOL)updateTunnelSettings:(BOOL)turnOn;

@end

NS_ASSUME_NONNULL_END
