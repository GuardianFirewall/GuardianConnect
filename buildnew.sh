#!/bin/bash

xcodebuild -sdk iphonesimulator
xcodebuild -sdk iphoneos

pwd=`pwd`
lipo=`which lipo`
cd build/Release-iphoneos

for i in `find * -name "*.framework"`; do

name=${i%\.*}
echo $name

done
#for i in *.framework ; do
#name=${i%\.*}
#echo $name
#echo "in here?"
#done

#echo $name
outputfile=$name.framework/$name
uniname=$outputfile.uni
fwpath=$pwd/build/Release-iphoneos/$name.framework
incpath=$pwd/build/Release-iphoneos/include
fullpath=$pwd/build/Release-iphoneos/$uniname

if [ -z "$name" ]; then

echo "empty name??"

for i in `find * -type f -name '*.a'`; do

name=${i%\.*}
echo $name

done

outputfile=$name.a
uniname=$outputfile.uni
fwpath=$pwd/build/Release-iphoneos/$name.a
incpath=$pwd/build/Release-iphoneos/include
fullpath=$pwd/build/Release-iphoneos/$uniname

fi

lipocmd="$lipo -create $outputfile ../Release-iphonesimulator/$outputfile -output $uniname"
echo $lipocmd
$lipocmd
echo $fullpath
chmod +x $uniname

if [ -f $fullpath ]; then

rm $outputfile
mv $uniname $outputfile
mv $fwpath ../..

if [ -d $incpath ]; then

    echo "found include path: $incpath"
    cp -r $incpath ../..

fi

echo "done!"

else

echo "The file does not exist";

fi



