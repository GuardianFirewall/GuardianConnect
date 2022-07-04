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
		.binaryTarget(
			name: "GuardianConnect",
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.6.2/GuardianConnect.xcframework.zip",
			checksum: "3f3108851f6b2d0aa30856197138390f4500d3763ba7b7d33c32ddd402f69f2d"
		)
	]
)
