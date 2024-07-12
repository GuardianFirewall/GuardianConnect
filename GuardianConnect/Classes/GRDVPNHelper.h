//
//  GRDVPNHelper.h
//  Guardian
//
//  Created by will on 4/28/19.
//  Copyright © 2019 Sudo Security Group Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NetworkExtension/NetworkExtension.h>

#import <GuardianConnect/Shared.h>
#import <GuardianConnect/GRDPEToken.h>
#import <GuardianConnect/GRDKeychain.h>
#import <GuardianConnect/GRDGatewayAPI.h>
#import <GuardianConnect/GRDTunnelManager.h>

#import <GuardianConnect/GRDTransportProtocol.h>
#import <GuardianConnect/GRDSubscriptionManager.h>
#import <GuardianConnect/GRDSubscriberCredential.h>
#import <GuardianConnect/GRDWireGuardConfiguration.h>

// Note from CJ 2022-02-02
// Using @class here for GRDRegion to prevent circular imports since
// we need GRDServerFeatureEnvironment in GRDRegion.h for a correct
// function signature
@class GRDRegion;

#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#endif
#import <GuardianConnect/GRDCredentialManager.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GRDServerFeatureEnvironment) {
	ServerFeatureEnvironmentProduction = 1,
	ServerFeatureEnvironmentInternal,
	ServerFeatureEnvironmentDevelopment,
	ServerFeatureEnvironmentDualStack,
	ServerFeatureEnvironmentUnstable
};

@interface GRDVPNHelper : NSObject {
	BOOL _preferBetaCapableServers;
	GRDServerFeatureEnvironment _featureEnvironment;
}

@property (readonly) BOOL 						preferBetaCapableServers;
@property (readonly) GRDServerFeatureEnvironment featureEnvironment;

/// a read only reference to the global NEVPNManager which handles
/// IKEv2 connections. This should be used as a read-only reference to convenient access
@property NEVPNManager *ikev2VPNManager;

/// The GuardianConnect API hostname to use for the majority of API calls
/// WARNING: Some API endpoints are always going to use the public Connect
/// API hostname https://connect-api.guardianapp.com
/// If no custom hostname is provided, the default public Connect API hostname is going to be used
@property (nonatomic, strong) NSString * _Nullable connectAPIHostname;

/// GuardianConnect app key used to authenticate API requests
@property (nonatomic, strong) NSString * _Nullable connectPublishableKey;

/// Keeps track of the current preferred Susbcriber Credential validation method
///
/// Setting this property will force the -getValidSubscriberCredentialWithCompletion: method
/// to always use the selected validation method during attempts to generate a new Subscriber Credential.
/// Use [GRDSubscriberCredential setPreferredValidationMethod:] to store the validation method preference
/// persistently. GRDVPNHelper will automatically pick the preference up during initialization
@property (nonatomic) GRDHousekeepingValidationMethod preferredSubscriberCredentialValidationMethod;

/// can be set to true to make - (void)getEvents return dummy alerts for debugging purposes
@property BOOL dummyDataForDebugging;

/// don't set this value manually, it is set upon the region selection code working successfully
@property (nullable) GRDRegion *selectedRegion;

/// Central callback block that apps should implement in order to be notified about
/// the device changing timezones
/// This block will be automatically called due to the SDK listening to the Apple provided
/// NSNotificationCenter NSSystemTimeZoneDidChangeNotification key as well as upon calling
/// -checkTimezoneChanged directly
@property (nonatomic, strong, nullable) void (^timezoneNotificationBlock)(BOOL changed, GRDRegion * _Nonnull oldRegion, GRDRegion * _Nonnull newRegion);

/// Do not assign this value directly if you would like the preference to persist across app launches.
/// Contains the preferred regionPrecision. Never nil and defaults to the constant string 'default'
///
/// In order to set a preferred region precision persistently use -setPreferredRegionPrecision:
@property (strong, nonatomic) NSString *regionPrecision;

/// Indicates whether load from preferences was successfull upon init
@property BOOL vpnLoaded;

/// If vpnLoaded == NO this will contain the error message return from NEVPNManager
@property (nullable) NSString *lastErrorMessage;

@property (nullable) NEProxySettings *proxySettings;

/// a separate reference is kept of the mainCredential because the credential manager instance needs to be fetched from preferences & the keychain every time its called.
@property (nullable) GRDCredential *mainCredential;

@property (readwrite, assign) BOOL onDemand; //defaults to yes

/// bool used to indicate whether the user wants the VPN to run in a super strict
/// mode, ensuring no data leaks. Puts the device into an almost unusable state
@property BOOL killSwitchEnabled;

/// This string will be used as the localized description of the NEVPNManager
/// configuration. The string will be visible in the network preferences on macOS
/// or in the VPN settings on iOS/iPadOS
///
/// Please note that this value is different than the grdTunnelProviderManagerLocalizedDescription
/// and it is not recommended to set the same values for both tunnels to avoid customers confusion
@property NSString *tunnelLocalizedDescription;

/// Indicate whether or not GRDVPNHelper should append a formatted server
/// location string at the end of the localized tunnel description string
///
/// Eg. "Guardian Firewall" -> "Guardian Firewall: Frankfurt, Germany"
@property BOOL appendServerRegionToTunnelLocalizedDescription;

/// Tunnel provider manager wrapper class to help with
/// starting and stopping a WireGuard VPN tunnel or a local tunnel.
@property GRDTunnelManager *tunnelManager;

/// Bundle Identifier string of the PacketTunnelProvider bundled with the main app.
/// May be omitted if WireGuard as the Transport Protocol or a local tunnel is not used.
/// It is recommended to set this up as early as possible
@property NSString *tunnelProviderBundleIdentifier;

/// This string will be used as the localized description of the NETunnelProviderManager
/// configuration. The string will be visible in the network preferences on macOS
/// or in the VPN settings on iOS/iPadOS
///
/// Please note that this value is different than the tunnelLocalizedDescription
/// and it is not recommended to set the same values for both tunnels to avoid customers confusion
@property NSString *grdTunnelProviderManagerLocalizedDescription;

/// Preferred DNS Server set here currently only apply to WireGuard VPN connections
///
/// Default: (Cloudflare) 1.1.1.1, 1.0.0.1
@property NSString *preferredDNSServers;

/// Enables or disables the device automatically
/// disconnecting the VPN once connected to trusted
/// WiFi networks.
/// Works with IKEv2 & WireGuard
///
/// This feature entirely relies on SSID strings as well as
/// the system trusting and connecting to a network. No additional
/// checks are performed if the SSID of the network matches the one
/// provided to this feature
@property BOOL disconnectOnTrustedNetworks;

/// Array of the names of trusted networks on which the VPN
/// will automatically disconnect with the help of the
/// NetworkExtension.framework on-demand rules capabiltity
/// Works with IKEv2 & WireGuard
///
/// In order to enable this feature please set disconnectOnTrustedNetworks to YES/true.
///
/// An empty array will lead to the feature not being enabled at all
@property NSArray<NSString *> * _Nullable trustedNetworks;

/// Indicate whether or not GRDVPNHelper should append a formatted server
/// location string at the end of the localized tunnel provider manager description string
///
/// Eg. "Guardian Firewall" -> "Guardian Firewall: Frankfurt, Germany"
@property BOOL appendServerRegionToGRDTunnelProviderManagerLocalizedDescription;

/// Constant used to make the WireGuard config in the local keychain
/// available to both the main app as well as the included Packet Tunnel Provider
/// app extension. Only used for WireGuard connections on iOS
@property NSString *appGroupIdentifier;

/// Set this key/value combinations to authenticate for custom
/// payment validation mechanisms already known to the Connect API
@property NSMutableDictionary *customSubscriberCredentialAuthKeys;

#if !TARGET_OS_OSX
@property UIBackgroundTaskIdentifier bgTask;
#endif

typedef NS_ENUM(NSInteger, GRDVPNHelperStatusCode) {
    GRDVPNHelperSuccess,
    GRDVPNHelperFail,
    GRDVPNHelperDoesNeedMigration,
    GRDVPNHelperMigrating,
    GRDVPNHelperNetworkConnectionError, // add other network errors
    GRDVPNHelperCoudNotReachAPIError,
    GRDVPNHelperApp_VpnPrefsLoadError,
    GRDVPNHelperApp_VpnPrefsSaveError,
    GRDVPNHelperAPI_AuthenticationError,
    GRDVPNHelperAPI_ProvisioningError
};

/// Always use the sharedInstance of this class, call it as early as possible in your application lifecycle to initialize the VPN preferences and load the credentials and VPN node connection information from the keychain.
+ (instancetype)sharedInstance;

/// Helper function to quickly determine if a VPN tunnel of any kind
/// with any transport protocol is established
- (BOOL)isConnected;

/// Helper function to quickly determine if a VPN tunnel of any kind
/// with any transport protocol is trying to establish the connection
- (BOOL)isConnecting;

/// retrieves values out of the system keychain and stores them in the sharedInstance singleton object in memory for other functions to use in the future
- (void)refreshVariables;

/// Used to determine if an active connection is possible, do we have all the necessary credentials (EAPUsername, Password, Host, etc)
+ (BOOL)activeConnectionPossible;

/// Used to clear all of our current VPN configuration details from user defaults and the keychain
+ (void)clearVpnConfiguration;

/// Send out two notifications to make any listener
/// aware that the hostname and hostname location values
/// should be updated in the interface
+ (void)sendServerUpdateNotifications;

/// Used to create a new VPN connection if an active subscription exists. This is the main function to call when no EAP credentials or subscriber credentials exist yet and you want to establish a new connection on a server that is chosen automatically for you.
/// @param mid block This is a block you can assign for when this process has approached a mid point (a server is selected, subscriber & eap credentials are generated). optional.
/// @param completion block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureFirstTimeUserPostCredential:(void(^ _Nullable)(void))mid completion:(void (^ _Nullable)(GRDVPNHelperStatusCode status, NSError *_Nullable error))completion;

/// Used to create a new VPN connection if an active subscription exists. This is the main function to call when no VPN credentials or a Subscriber Credential exist yet and a new connection should be established to a server chosen automatically.
/// @param protocol The desired transport protocol to use to establish the connection. IKEv2 (builtin) as well as WireGuard via a PacketTunnelProvider are supported
/// @param postCredentialCallback This is a block you can assign for when this process has approached a mid point (a server is selected, subscriber & eap credentials are generated). optional.
/// @param completion This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol postCredentialCallback:(void (^ _Nullable)(void))postCredentialCallback completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

/// Used to create a new VPN connection if an active subscription exists. This method will allow you to specify a host, a host location, a postCredential block and a completion block.
/// @param protocol The desired transport protocol to use to establish the connection. IKEv2 (builtin) as well as WireGuard via a PacketTunnelProvider are supported
/// @param region GRDRegion, the region to create fresh VPN connection to, upon nil it will revert to automatic selection based upon the users current time zone.
/// @param completion block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureFirstTimeUserForTransportProtocol:(TransportProtocol)protocol withRegion:(GRDRegion * _Nullable)region completion:(void(^__nullable)(GRDVPNHelperStatusCode status, NSError * _Nullable error))completion;

/// Used to create a new VPN connection if an active subscription exists. This method will allow you to specify a transport protocol, host, a host location, a postCredential callback block and a completion block.
/// @param protocol The desired transport protocol to use to establish the connection. IKEv2 (builtin) as well as WireGuard via a PacketTunnelProvider are supported
/// @param server GRDSGWServer reference passing hostname, host display name as well as GRDRegion reference to be processed within the function
/// @param mid block This is a block you can assign for when this process has approached a mid point (a server is selected, subscriber & eap credentials are generated). optional.
/// @param completion block This is a block that will return upon completion of the process, if success is TRUE and errorMessage is nil then we will be successfully connected to a VPN node.
- (void)configureUserFirstTimeForTransportProtocol:(TransportProtocol)protocol server:(GRDSGWServer * _Nonnull)server postCredential:(void(^__nullable)(void))mid completion:(void (^_Nullable)(GRDVPNHelperStatusCode status, NSError *_Nullable errorMessage))completion;

/// Used subsequently after the first time connection has been successfully made to re-connect to the current host VPN node with mainCredentials
/// @param completion block This completion block will return an error to display to the user and a status code, if the connection is successful, the error will be empty.
- (void)configureAndConnectVPNTunnelWithCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode status, NSError * _Nullable errorMessage))completion;

/// Used to disconnect from the current VPN node
///
/// The sibling to this function - (void) disconnectVPN does not expose various potential errors as it tries to mitigate various OS bugs as well as trigger race conditions
/// to provide the expected behavior to begin with.
///
/// This function might be hazardous to your health
/// - Parameter completion: completion block potentially containing an error message. This completion block may be called multiple times and could potentially include an error every time
- (void)disconnectVPNWithCompletion:(void (^_Nullable)(NSError * _Nullable error))completion;

/// Safely disconnect from the current VPN node if applicable. This is best to call upon doing disconnections upon app launches. For instance, if a subscription expiration has been detected on launch, disconnect the active VPN connection. This will make certain not to disconnect the VPN if a valid state isnt detected.
- (void)forceDisconnectVPNIfNecessary;

/// This is a convenience function to reset the state of the SDK back
/// as though the device had never connected to a VPN before.
///
/// This app should specifically be called after the
/// app launches on a device for the first time
- (void)resetAllGuardianConnectValues;

/// There should be no need to call this directly, this is for internal use only.
- (void)getValidSubscriberCredentialWithCompletion:(void(^)(GRDSubscriberCredential * _Nullable subscriberCredential, NSError * _Nullable error))completion;


/// Used to create standalone VPN credentials on a specified host that is valid for a certain number of days. Good for exporting VPN credentials for use on other devices.
/// @param protocol The desired transport protocol to use to establish the connection. IKEv2 (builtin) as well as WireGuard via a PacketTunnelProvider are supported
/// @param days NSInteger number of days these credentials will be valid for
/// @param server GRDSGWServer containing the hostname to connect to ie: frankfurt-10.sgw.guardianapp.com
/// @param completion block Completion block that will contain an NSDictionary of credentials upon success
- (void)createStandaloneCredentialsForTransportProtocol:(TransportProtocol)protocol validForDays:(NSInteger)days server:(GRDSGWServer *)server completion:(void (^)(NSDictionary * _Nullable credentials, NSError * _Nullable errorMessage))completion;

/// Verify that the current main VPN credentials are valid if applicable. 
/// A valid Subscriber Credential is automatically obtained and provided to
/// the VPN node alongside the credential details.
/// If the device is currently connected and the server indicates that
/// the VPN credentials are no longer valid the device is automatically
/// migrated to a new server within the same region
- (void)verifyMainCredentialsWithCompletion:(void(^)(BOOL valid, NSError * _Nullable errorMessage))completion;

/// Call this to properly assign a GRDRegion to all GRDServerManager instances
/// @param region the region to select a server from. Pass nil to reset to Automatic region selection mode
- (NSError * _Nullable)selectRegion:(GRDRegion * _Nullable)region;

/// Function to trigger manual verification whether or not the device's time zone
/// has changed to notify the app to either automatically migrate or let the user
/// know about it and take action on it to ensure that the user always uses the best
/// server available to them.
/// The app will be notified by implementing the propery @timezoneNotificationBlock
- (void)checkTimezoneChanged;

/// Sets the preferred region precision persistently for the SDK to request VPN hostnames with
///
/// The constants 'kGRDRegionPrecisionDefault', 'kGRDRegionPrecisionCity' or 'kGRDRegionPrecisionCountry' should be used
/// @param precision the preferred region precision
- (void)setPreferredRegionPrecision:(NSString * _Nonnull)precision;

/// Convenience function to store trusted networks persistently and enabling the feature
///
/// The array of trusted network SSIDs will be stored in NSUserDefaults and
/// the trustedNetworks property will be populated to read it back.
/// Providing nil will disable the feature and remove the array of trusted networks
/// out of NSUserDefaults
- (void)defineTrustedNetworksEnabled:(BOOL)enabled onTrustedNetworks:(NSArray<NSString *> *)trustedNetworks;

- (void)allRegionsWithCompletion:(void (^)(NSArray <GRDRegion *> * _Nullable regions, NSError * _Nullable error))completion;

/// Migrate the user to a new server for the user preferred transport protocol. A new server will be selected, new credentials will be generated and finally the VPN tunnel will be established with the new credentials on the new server.
- (void)migrateUserForTransportProtocol:(TransportProtocol)protocol withCompletion:(void (^_Nullable)(GRDVPNHelperStatusCode statusCode, NSError * _Nullable error))completion;

/// Clear all on device cache related to cached Guardian hosts & keychain items including the Subscriber Credential
- (void)clearLocalCache;

@end

NS_ASSUME_NONNULL_END
