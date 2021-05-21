#!/bin/bash

sudo defaults write /Library/Preferences/com.apple.networkextension.control.plist LogToFile -boolean true
sudo defaults write /Library/Preferences/com.apple.networkextension.control.plist LogLevel -int 7


/System/Library/Frameworks/SystemConfiguration.framework/Resources/get-mobility-info
