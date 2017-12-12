// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Gravl",
	products: [
		.library(name: "Gravl", targets: ["Gravl"]),
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "Gravl",
			path: "Sources/1.1"),
	]
)
