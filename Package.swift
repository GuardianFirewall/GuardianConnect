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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.8.0-dev-4/GuardianConnect.xcframework.zip",
			checksum: "3fe4d19acfa035957fd91ce29bbc5c1f8c0cb06b0c966243db2dd473a3fe4bf5"
		)
	]
)
