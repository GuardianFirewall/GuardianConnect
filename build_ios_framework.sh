#!/bin/bash

# clear previous build folder if it exist
rm -rf build

# build simulator and iphoneos frameworks
xcodebuild -sdk iphonesimulator
xcodebuild -sdk iphoneos

# keep track of our current working directory
pwd=$(pwd)

# change to the release-iphoneos folder to get the name of the framework (this is to make this script more universal)

pushd build/Release-iphoneos || exit

# find the name of the framework, in our case 'GuardianConnect'

for i in $(find * -name "*.framework"); do

    name=${i%\.*}
    echo "$name"

done

# remove the old copy of the xcframework if it already exists

rm -rf ../../"$name".xcframework

# pop back to the GuardianConnect folder

popd || exit

# create variables for the path to each respective framework

ios_fwpath=$pwd/build/Release-iphoneos/$name.framework

sim_fwpath=$pwd/build/Release-iphonesimulator/$name.framework

# create the xcframework

xcodebuild -create-xcframework -framework "$ios_fwpath" -framework "$sim_fwpath" -output "$name".xcframework




