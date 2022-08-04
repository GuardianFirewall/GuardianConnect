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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.7/GuardianConnect.xcframework.zip",
			checksum: "bbec6dd3e1b336c5616743787b1fdffdc644aaeef0d4de924754af9c0745d5a8"
		)
	]
)
