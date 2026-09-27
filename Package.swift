// swift-tools-version: 6.0
// FallKit: standalone Swift package kits for iOS apps.
// Layout and rules: CLAUDE.md. One folder per kit under Sources/ and Tests/.

import PackageDescription

let package = Package(
    name: "FallKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        // macOS is for `swift test` and the CLI only; no app ships on it.
        .macOS(.v14),
    ],
    products: [
        .library(name: "LiveOpsCore", targets: ["LiveOpsCore"]),
        .library(name: "LiveOpsStore", targets: ["LiveOpsStore"]),
        .library(name: "LiveOpsFirebase", targets: ["LiveOpsFirebase"]),
        .library(name: "LiveOpsTesting", targets: ["LiveOpsTesting"]),
        .executable(name: "liveops", targets: ["LiveOpsCLI"]),
    ],
    dependencies: [
        // A range, not an exact version: an app keeps its own exact pin and SwiftPM
        // resolves one copy. 12.17.0 is the lowest version the consumer check builds.
        // Apps must spell the URL the same way for SwiftPM to see one package.
        .package(url: "https://github.com/firebase/firebase-ios-sdk", "12.17.0"..<"13.0.0"),
    ],
    targets: [
        // MARK: LiveOpsKit

        .target(
            name: "LiveOpsCore",
            path: "Sources/LiveOps/Core"
        ),
        .target(
            name: "LiveOpsStore",
            dependencies: ["LiveOpsCore"],
            path: "Sources/LiveOps/Store"
        ),
        .target(
            name: "LiveOpsFirebase",
            dependencies: [
                "LiveOpsStore",
                // iOS only: `swift test` on macOS and watchOS builds never compile Firebase.
                // The transport is wrapped in `#if canImport(FirebaseRemoteConfig)`.
                .product(
                    name: "FirebaseRemoteConfig",
                    package: "firebase-ios-sdk",
                    condition: .when(platforms: [.iOS])
                ),
            ],
            path: "Sources/LiveOps/Firebase"
        ),
        .target(
            name: "LiveOpsTesting",
            dependencies: ["LiveOpsStore"],
            path: "Sources/LiveOps/Testing",
            resources: [.copy("Fixtures")]
        ),
        .executableTarget(
            name: "LiveOpsCLI",
            dependencies: ["LiveOpsCore"],
            path: "Sources/LiveOps/CLI"
        ),

        .testTarget(
            name: "LiveOpsCoreTests",
            dependencies: ["LiveOpsCore", "LiveOpsTesting"],
            path: "Tests/LiveOps/CoreTests"
        ),
        .testTarget(
            name: "LiveOpsStoreTests",
            dependencies: ["LiveOpsStore", "LiveOpsTesting"],
            path: "Tests/LiveOps/StoreTests"
        ),
        .testTarget(
            name: "LiveOpsCLITests",
            dependencies: ["LiveOpsCLI", "LiveOpsCore", "LiveOpsTesting"],
            path: "Tests/LiveOps/CLITests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
