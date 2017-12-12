// swift-tools-version:4.0

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
