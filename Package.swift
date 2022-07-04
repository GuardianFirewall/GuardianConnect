//
//  Package.swift
//  GuardianConnect
//
// swift-tools-version:5.3
//

import PackageDescription

let package = Package(
	name: "GuardianConnect",
	platforms: [
		.macOS(.v10.15),
		.iOS(.v13)
	],
	products: [
		.library(name: "GuardianConnect", targets: ["GuardianConnect", "GuardianConnectMac"])
	],
	targets: [
		.binaryTarget(name: "GuardianConnect", url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.6/GuardianConnect.xcframework.zip")
	]
)
