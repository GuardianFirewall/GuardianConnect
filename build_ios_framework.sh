#!/bin/bash

# search for 'xcpretty' will make the build output much tinier and easier to read / digest.
XCP=$(which xcpretty)
echo $XCP

# clear previous build folder if it exist
rm -rf build

# build simulator and iphoneos frameworks

# -z checks to see if a value is empty, if xcpretty is not found, build normally, if it is found then use it to clean up our output.
if [ -z $XCP ]; then
    echo ""
    echo "xcpretty was not found, recommending its installion to clean up this build script output! 'gem install xcpretty' to install it!"
    echo ""
    xcodebuild -sdk iphonesimulator
    xcodebuild -sdk iphoneos
else
    xcodebuild -sdk iphonesimulator | $XCP
    xcodebuild -sdk iphoneos | $XCP
fi

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




