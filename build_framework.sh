#!/bin/bash

# clear previous build folders if it exist
rm -rf build
rm -rf build-archives

# remove the old copy of the xcframework if it already exists
rm -rf GuardianConnect.xcframework

# remove the old copy of the xcframework zip if it already exists
rm -rf GuardianConnect.xcframework.zip

# build simulator and iphoneos frameworks

# -z checks to see if a value is empty, if xcpretty is not found, build normally, if it is found then use it to clean up our output.

xcodebuild clean archive -scheme GuardianConnect -target GuardianConnect -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -archivePath './build-archives/GuardianConnect-iossimulator.xcarchive'
xcodebuild clean archive -scheme GuardianConnect -target GuardianConnect -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -archivePath './build-archives/GuardianConnect-ios.xcarchive'
xcodebuild clean archive -scheme GuardianConnectMac -target GuardianConnectMac -configuration Release -sdk macosx -archivePath './build-archives/GuardianConnect-macos.xcarchive'


# keep track of our current working directory
pwd=$(pwd)

# create variables for the path to each respective framework
ios_fwpath="$pwd/build-archives/GuardianConnect-ios.xcarchive/Products/Library/Frameworks/GuardianConnect.framework"
ios_debugpath="$pwd/build-archives/GuardianConnect-ios.xcarchive/dSYMs/GuardianConnect.framework.dSYM"
sim_fwpath="$pwd/build-archives/GuardianConnect-iossimulator.xcarchive/Products/Library/Frameworks/GuardianConnect.framework"
sim_debugpath="$pwd/build-archives/GuardianConnect-iossimulator.xcarchive/dSYMs/GuardianConnect.framework.dSYM"
mac_path="$pwd/build-archives/GuardianConnect-macos.xcarchive/Products/Library/Frameworks/GuardianConnect.framework"
mac_debugpath="$pwd/build-archives/GuardianConnect-macos.xcarchive/dSYMs/GuardianConnect.framework.dSYM"

# create the xcframework
xcodebuild -create-xcframework -framework "$ios_fwpath" -debug-symbols "$ios_debugpath" -framework "$sim_fwpath" -debug-symbols "$sim_debugpath" -framework "$mac_path" -debug-symbols "$mac_debugpath" -output GuardianConnect.xcframework

printf "\n\n"
printf "Proccesing SwiftPM artifacts\n"

printf "Creating .zip archive...\n"
# create .zip of the framework for SwiftPM
ditto -c -k --sequesterRsrc --keepParent "./GuardianConnect.xcframework" "./GuardianConnect.xcframework.zip"

printf "Done 🎉\n"

printf "\n"
printf "SwiftPM .zip checksum:\n"
# get hash checksum for SwiftPM
swift package compute-checksum "./GuardianConnect.xcframework.zip"

open -R GuardianConnect.xcframework.zip
