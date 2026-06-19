// swift-tools-version:5.9
import PackageDescription

// Lightweight package that compiles ONLY the pure, dependency-free SRS logic so
// it can be unit-tested in CI without Xcode / a simulator (the app itself is an
// .xcodeproj). These files import nothing beyond Foundation, so `swift test`
// runs on a plain Linux runner.
//
// This package and the Xcode app build the same source files; it does not
// replace the app project.
let package = Package(
    name: "SRSCore",
    products: [
        .library(name: "SRSCore", targets: ["SRSCore"]),
    ],
    targets: [
        .target(
            name: "SRSCore",
            path: "scripture memory/Model",
            sources: [
                "SRSAlgorithm.swift",
                "SRSCardState.swift",
                "SRSMath.swift",
            ]
        ),
        .testTarget(
            name: "SRSCoreTests",
            dependencies: ["SRSCore"],
            path: "Tests/SRSCoreTests"
        ),
    ]
)
