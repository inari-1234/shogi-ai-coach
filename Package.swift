// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShogiCoach",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShogiCoachCore", targets: ["ShogiCoachCore"]),
        .executable(name: "ContextKnowledgeBuilder", targets: ["ContextKnowledgeBuilder"])
    ],
    targets: [
        .target(name: "ShogiCoachCore"),
        .executableTarget(name: "ContextKnowledgeBuilder", dependencies: ["ShogiCoachCore"]),
        .testTarget(name: "ShogiCoachCoreTests", dependencies: ["ShogiCoachCore"])
    ]
)
