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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.8.2-dev-1/GuardianConnect.xcframework.zip",
			checksum: "fe5de8a4a6718e68bf18c6444dc72a60f88974b286789e7c2bfb1b8fb93639c5"
		)
	]
)
