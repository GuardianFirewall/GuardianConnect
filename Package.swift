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
		.library(name: "GuardianConnect", targets: ["GuardianConnect"])
	],
	targets: [
		.binaryTarget(
			name: "GuardianConnect",
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.8.7-dev-1/GuardianConnect.xcframework.zip",
			checksum: "d83d9f8c6f4ecd5a33704b718a9064567b1d64aba7d0940156e18e653c4af377"
		)
	]
)
