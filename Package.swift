// swift-tools-version:5.6
//
//  Package.swift
//  GuardianConnect
//
//

import PackageDescription

let package = Package(
	name: "GuardianConnect",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13)
	],
	products: [
		.library(name: "GuardianConnect", targets: ["GuardianConnect", "GuardianConnectMac"])
	],
	targets: [
		.binaryTarget(name: "GuardianConnect", url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.6.0/GuardianConnect.xcframework.zip")
	]
)
