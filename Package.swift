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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.7.0/GuardianConnect.xcframework.zip",
			checksum: "7898565554ba01afd0ded62c9fca2ecd231fb79645e33a757bcc15d4f0782c5a"
		)
	]
)
