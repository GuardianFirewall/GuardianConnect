#!/bin/bash

# This is used to turn on file / verbose logging of the NetworkExtension framework (framework used for VPN access) and to create debug information compressed into a tar file (get-mobility-info does that part)

sudo defaults write /Library/Preferences/com.apple.networkextension.control.plist LogToFile -boolean true
sudo defaults write /Library/Preferences/com.apple.networkextension.control.plist LogLevel -int 7

/System/Library/Frameworks/SystemConfiguration.framework/Resources/get-mobility-info
