// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShogiCoach",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShogiCoachCore", targets: ["ShogiCoachCore"]),
        .executable(name: "ContextKnowledgeBuilder", targets: ["ContextKnowledgeBuilder"]),
        .executable(name: "Build17RealGameRegression", targets: ["Build17RealGameRegression"])
    ],
    targets: [
        .target(name: "ShogiCoachCore"),
        .executableTarget(name: "ContextKnowledgeBuilder", dependencies: ["ShogiCoachCore"]),
        .executableTarget(name: "Build17RealGameRegression", dependencies: ["ShogiCoachCore"]),
        .testTarget(name: "ShogiCoachCoreTests", dependencies: ["ShogiCoachCore"])
    ]
)
