// swift-tools-version: 6.0
import Foundation
import PackageDescription

// PingRecognize depends on KeylessSDK, which is distributed through a private
// Swift package registry (Cloudsmith). The dependency is only included when
// that registry is configured on the machine, so the rest of the SDK and the
// sample apps keep building for users without registry credentials.
let hasKeylessRegistry: Bool = {
    // Detects a configured Keyless registry: a marker file inside the package
    // (checked first, since it's readable even inside xcodebuild's manifest
    // evaluation sandbox) or, as a fallback for CLI usage, the user's SwiftPM
    // registries.json configuration.
    let markerPath = URL(fileURLWithPath: #file).deletingLastPathComponent()
        .appendingPathComponent("Recognize/.registry-enabled").path
    if FileManager.default.fileExists(atPath: markerPath) {
        return true
    }

    let homeDirectory = ProcessInfo.processInfo.environment["HOME"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? FileManager.default.homeDirectoryForCurrentUser
    let configurationPath = homeDirectory
        .appendingPathComponent(".swiftpm/configuration/registries.json")

    guard
        let data = try? Data(contentsOf: configurationPath),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let registries = json["registries"] as? [String: Any]
    else {
        return false
    }

    return registries["keyless"] != nil
}()

var products: [Product] = [
        // MARK: - Foundation
        .library(name: "PingLogger", targets: ["PingLogger"]),
        .library(name: "PingStorage", targets: ["PingStorage"]),
        
        // MARK: - Core
        .library(name: "PingNetwork", targets: ["PingNetwork"]),
        .library(name: "PingCommons", targets: ["PingCommons"]),
        .library(name: "PingBrowser", targets: ["PingBrowser"]),
        .library(name: "PingOrchestrate", targets: ["PingOrchestrate"]),
        
        // MARK: - Plugins
        .library(name: "PingDavinciPlugin", targets: ["PingDavinciPlugin"]),
        .library(name: "PingJourneyPlugin", targets: ["PingJourneyPlugin"]),
        
        // MARK: - Authentication
        .library(name: "PingOidc", targets: ["PingOidc"]),
        .library(name: "PingDavinci", targets: ["PingDavinci"]),
        .library(name: "PingJourney", targets: ["PingJourney"]),
        
        // MARK: - Device
        .library(name: "PingDeviceId", targets: ["PingDeviceId"]),
        .library(name: "PingDeviceProfile", targets: ["PingDeviceProfile"]),
        .library(name: "PingDeviceClient", targets: ["PingDeviceClient"]),
        .library(name: "PingTamperDetector", targets: ["PingTamperDetector"]),
        
        // MARK: - External Identity Providers
        .library(name: "PingExternalIdP", targets: ["PingExternalIdP"]),
        .library(name: "PingExternalIdPApple", targets: ["PingExternalIdPApple"]),
        .library(name: "PingExternalIdPGoogle", targets: ["PingExternalIdPGoogle"]),
        .library(name: "PingExternalIdPFacebook", targets: ["PingExternalIdPFacebook"]),
        
        // MARK: - Security & Protection
        .library(name: "PingProtect", targets: ["PingProtect"]),
        .library(name: "PingReCaptchaEnterprise", targets: ["PingReCaptchaEnterprise"]),
        .library(name: "PingFido", targets: ["PingFido"]),
        
        // MARK: - MFA
        .library(name: "PingOath", targets: ["PingOath"]),
        .library(name: "PingPush", targets: ["PingPush"]),
        .library(name: "PingAuthMigration", targets: ["PingAuthMigration"]),
        .library(name: "PingOneMFA", targets: ["PingOneMFA"]),
        
        // MARK: - Utilities
        .library(name: "PingBinding", targets: ["PingBinding"]),
]

var dependencies: [Package.Dependency] = [
        // External dependencies
        .package(url: "https://github.com/pingidentity/pingone-signals-sdk-ios.git", "5.4.0"..<"5.5.0"),
        .package(url: "https://github.com/facebook/facebook-ios-sdk.git", "18.1.0"..<"19.0.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", exact: "9.0.0"),
        .package(url: "https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk.git", "18.9.1"..<"18.10.0"),
        .package(url: "https://github.com/pingidentity/pingone-mobile-sdk-ios.git", exact: "2.3.1")
]

var targets: [Target] = [
        // MARK: - Foundation Targets (No dependencies)
        .target(
            name: "PingLogger",
            dependencies: [],
            path: "Logger/Logger",
            exclude: ["Logger.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingStorage",
            dependencies: [],
            path: "Storage/Storage",
            exclude: ["Storage.h", "CACHING_GUIDE.md"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - Core Targets
        .target(
            name: "PingNetwork",
            dependencies: ["PingLogger"],
            path: "Network/Network",
            exclude: ["Network.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingCommons",
            dependencies: ["PingLogger"],
            path: "Commons/Commons",
            exclude: ["Commons.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingBrowser",
            dependencies: ["PingLogger"],
            path: "Browser/Browser",
            exclude: ["Browser.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingOrchestrate",
            dependencies: [
                "PingStorage",
                "PingNetwork"
            ],
            path: "Orchestrate/Orchestrate",
            exclude: ["Orchestrate.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - Plugin Targets
        .target(
            name: "PingDavinciPlugin",
            dependencies: ["PingOrchestrate"],
            path: "DavinciPlugin/DavinciPlugin",
            exclude: ["DavinciPlugin.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingJourneyPlugin",
            dependencies: ["PingOrchestrate"],
            path: "JourneyPlugin/JourneyPlugin",
            exclude: ["JourneyPlugin.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - Authentication Targets
        .target(
            name: "PingOidc",
            dependencies: [
                "PingOrchestrate",
                "PingBrowser",
                "PingCommons"
            ],
            path: "Oidc/Oidc",
            exclude: ["Oidc.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingDavinci",
            dependencies: [
                "PingDavinciPlugin",
                "PingOidc"
            ],
            path: "Davinci/Davinci",
            exclude: ["Davinci.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingJourney",
            dependencies: [
                "PingDeviceProfile",
                "PingJourneyPlugin",
                "PingOidc"
            ],
            path: "Journey/Journey",
            exclude: ["Journey.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - Device Targets
        .target(
            name: "PingDeviceId",
            dependencies: [
                "PingLogger",
                "PingStorage"
            ],
            path: "DeviceId/DeviceId",
            exclude: ["DeviceId.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingTamperDetector",
            dependencies: ["PingCommons"],
            path: "TamperDetector/TamperDetector",
            exclude: ["TamperDetector.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingDeviceProfile",
            dependencies: [
                "PingDeviceId",
                "PingJourneyPlugin",
                "PingTamperDetector"
            ],
            path: "DeviceProfile/DeviceProfile",
            exclude: ["DeviceProfile.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingDeviceClient",
            dependencies: [
                "PingCommons",
                "PingNetwork"
            ],
            path: "DeviceClient/DeviceClient",
            exclude: ["DeviceClient.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - External IdP Targets
        .target(
            name: "PingExternalIdP",
            dependencies: [
                "PingBrowser",
                "PingDavinciPlugin",
                "PingJourneyPlugin"
            ],
            path: "ExternalIdP/ExternalIdP",
            exclude: ["ExternalIdP.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingExternalIdPApple",
            dependencies: ["PingExternalIdP"],
            path: "ExternalIdPApple/ExternalIdPApple",
            exclude: ["ExternalIdPApple.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingExternalIdPGoogle",
            dependencies: [
                "PingExternalIdP",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS", condition: .when(platforms: [.iOS]))
            ],
            path: "ExternalIdPGoogle/ExternalIdPGoogle",
            exclude: ["ExternalIdPGoogle.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingExternalIdPFacebook",
            dependencies: [
                "PingExternalIdP",
                .product(name: "FacebookLogin", package: "facebook-ios-sdk", condition: .when(platforms: [.iOS]))
            ],
            path: "ExternalIdPFacebook/ExternalIdPFacebook",
            exclude: ["ExternalIdPFacebook.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - Security & Protection Targets
        .target(
            name: "PingProtect",
            dependencies: [
                "PingDavinciPlugin",
                "PingJourneyPlugin",
                .product(name: "PingOneSignals", package: "pingone-signals-sdk-ios", condition: .when(platforms: [.iOS]))
            ],
            path: "Protect/Protect",
            exclude: ["Protect.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingReCaptchaEnterprise",
            dependencies: [
                "PingCommons",
                "PingJourneyPlugin",
                .product(name: "RecaptchaEnterprise", package: "recaptcha-enterprise-mobile-sdk", condition: .when(platforms: [.iOS]))
            ],
            path: "ReCaptchaEnterprise/ReCaptchaEnterprise",
            exclude: ["ReCaptchaEnterprise.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingFido",
            dependencies: [
                "PingLogger",
                "PingCommons",
                "PingDavinciPlugin",
                "PingJourneyPlugin"
            ],
            path: "Fido/Fido",
            exclude: ["Fido.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        
        // MARK: - MFA Targets
        .target(
            name: "PingOath",
            dependencies: ["PingTamperDetector"],
            path: "Oath/Oath",
            exclude: ["Oath.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingPush",
            dependencies: [
                "PingNetwork",
                "PingTamperDetector"
            ],
            path: "Push/Push",
            exclude: ["Push.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingAuthMigration",
            dependencies: [
                "PingOath",
                "PingPush"
            ],
            path: "AuthMigration/AuthMigration",
            exclude: ["AuthMigration.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PingOneMFA",
            dependencies: [
                .product(name: "PingOneSDK", package: "pingone-mobile-sdk-ios")
            ],
            path: "PingOneMFA/PingOneMFA",
            exclude: ["PingOneMFA.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),

        // MARK: - Utility Targets
        .target(
            name: "PingBinding",
            dependencies: [
                "PingCommons",
                "PingDeviceId",
                "PingJourneyPlugin"
            ],
            path: "Binding/Binding",
            exclude: ["Binding.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ]

if hasKeylessRegistry {
    products.append(
        .library(name: "PingRecognize", targets: ["PingRecognize"])
    )

    dependencies.append(
        .package(id: "keyless.mobile-sdk", from: "6.0.0")
    )

    targets.append(
        .target(
            name: "PingRecognize",
            dependencies: [
                "PingJourneyPlugin",
                .product(name: "KeylessSDK", package: "keyless.mobile-sdk", condition: .when(platforms: [.iOS]))
            ],
            path: "Recognize/Recognize",
            exclude: ["Recognize.h"],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    )

    targets.append(
        .testTarget(
            name: "RecognizeTests",
            dependencies: [
                "PingRecognize",
                .product(name: "KeylessSDK", package: "keyless.mobile-sdk", condition: .when(platforms: [.iOS]))
            ],
            path: "Recognize/RecognizeTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    )
}

let package = Package(
    name: "Ping-SDK-iOS",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
