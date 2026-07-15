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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/2.2.0/GuardianConnect.xcframework.zip",
			checksum: "ef2f7592184ca1b0638c7888a84f2e174dfe986f360d115d616773c668fea46d"
		)
	]
)
