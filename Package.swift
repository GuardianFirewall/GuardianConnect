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
			url:"https://github.com/GuardianFirewall/GuardianConnect/releases/download/1.8.0-dev-11/GuardianConnect.xcframework.zip",
			checksum: "59e7cca07f396e7f3ab4b8ae3d179e6cdef6e38b01f0871e3a7dc0b87998149b"
		)
	]
)
