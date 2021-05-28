# GuardianConnect
API / VPN Framework for Guardian Firewall iOS application

To build an xcframework for iOS or mac change into the root folder and run OR change to the target XCFramework and build straight from Xcode

./build_framework.sh

if all goes well you should have GuardianConnect.xcframework in that folder upon completion.

There is now a sample POC macintosh client available in the repo it is almost completely fully featured, including blocklist support & in app purchases.

There is also an iOS sample project in Swift to show how easy it is to integrate with either language. (Obj-C or Swift)

## VPN trouble shooting

If you are attempting a macOS VPN client the following scripts can potentially be helpful to enable debug logging:

disable_macos_debug_logging.sh & enable_macos_debug_logging.sh to toggle the logging on and off respectively.

