#!/bin/bash

# This is used to undo the changes made by enable_macos_debug_logging.sh and will turn off file / verbose logging of the NetworkExtension framework (framework used for VPN access)

sudo defaults delete /Library/Preferences/com.apple.networkextension.control.plist LogToFile
sudo defaults delete /Library/Preferences/com.apple.networkextension.control.plist LogLevel
