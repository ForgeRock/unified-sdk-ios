// swift-tools-version:5.3
import PackageDescription

let package = Package (
    name: "PingOne-unified-sdk-ios",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "PingLogger", targets: ["PingLogger"]),
        .library(name: "PingStorage", targets: ["PingStorage"]),
        .library(name: "PingOrchestrate", targets: ["PingOrchestrate"]),
        .library(name: "PingOidc", targets: ["PingOidc"]),
        .library(name: "PingDavinci", targets: ["PingDavinci"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "PingLogger", dependencies: [], path: "PingLogger/PingLogger", exclude: ["PingLogger.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingStorage", dependencies: [], path: "PingStorage/PingStorage", exclude: ["PingStorage.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOrchestrate", dependencies: [.target(name: "PingLogger"), .target(name: "PingStorage")], path: "PingOrchestrate/PingOrchestrate", exclude: ["PingOrchestrate.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingOidc", dependencies: [.target(name: "PingOrchestrate")], path: "PingOidc/PingOidc", exclude: ["PingOidc.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "PingDavinci", dependencies: [.target(name: "PingOidc"),], path: "PingDavinci/PingDavinci", exclude: ["PingDavinci.h"], resources: [.copy("PrivacyInfo.xcprivacy")]),
    ]
)
