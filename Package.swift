// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShogiCoach",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShogiCoachCore", targets: ["ShogiCoachCore"])
    ],
    targets: [
        .target(name: "ShogiCoachCore"),
        .testTarget(name: "ShogiCoachCoreTests", dependencies: ["ShogiCoachCore"])
    ]
)
