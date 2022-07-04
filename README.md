# GuardianConnect

A complete framework for iOS and macOS applications written in Objective-C or Swift to integrate with the Guardian Connect API and establish VPN connections to the Guardian Firewall infrastructure. All lower lever components are exposed but the use of high level APIs in `GRDVPNHelper` are recommended.  
This framework includes everything to establish an IKEv2 connection through the builtin IKEv2 daemon on iOS & macOS, as well as a WireGuard connection through an external library provided by Guardian.  
_(The WireGuard library is not required to build this framework locally)_

For more information and a direct contact visit https://guardianapp.com/company/partners/

### Integration
Pre-built frameworks will be made available with significant advances through the releases feature here on Github and new updates can either be manually downloaded or automated through SwiftPM.

**¡We strongly encourage everybody to explicitly pin specific version numbers if used with SwiftPM!**

The framework is considered stable and breaking changes will be handled through new code paths to preserve existing stable ones. Bug fixes or OS API changes may change the behavior of the framework unintentionally.


### Manual build
The framework can also easily be built locally and does not depend on any other external downloads. A combination of a complete download of this repo as well as the Xcode toolchain should will give you a locally built .xcframework file with slices for iOS & macOS

#### Shell
To build an xcframework for iOS or macOS `cd` into the root folder and run the following command

`./build_framework.sh`

#### Xcode
Another way to execute the shell script to build the .xcframework locally is to use the `XCFramework` build target in Xcode. Once selected use the `Build` feature in Xcode to generate the framework.

Both build strategies will open a new Finder window once the framework was successfully built and highlight the newly built `GuardianConnect.xcframework` file. This can now be placed into Xcode via drag & drop

