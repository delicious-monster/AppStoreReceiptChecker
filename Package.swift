// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "AppStoreReceiptChecker",
    platforms: [
        .macOS(.v10_12)
    ],
    products: [
        .library(name: "AppStoreReceiptChecker", targets: ["AppStoreReceiptChecker"]),
    ],
    targets: [
        .target(name: "AppStoreReceiptChecker", path: "Sources")
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
