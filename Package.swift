// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShogiCoach",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShogiCoachCore", targets: ["ShogiCoachCore"]),
        .executable(name: "ContextKnowledgeBuilder", targets: ["ContextKnowledgeBuilder"]),
        .executable(name: "Build17RealGameRegression", targets: ["Build17RealGameRegression"]),
        .executable(name: "Build19VSemanticAudit", targets: ["Build19VSemanticAudit"]),
        .executable(name: "VE1BLegalRootCrosscheck", targets: ["VE1BLegalRootCrosscheck"])
    ],
    targets: [
        .target(name: "ShogiCoachCore"),
        .executableTarget(name: "ContextKnowledgeBuilder", dependencies: ["ShogiCoachCore"]),
        .executableTarget(name: "Build17RealGameRegression", dependencies: ["ShogiCoachCore"]),
        .executableTarget(name: "Build19VSemanticAudit", dependencies: ["ShogiCoachCore"]),
        .executableTarget(name: "VE1BLegalRootCrosscheck", dependencies: ["ShogiCoachCore"]),
        .testTarget(name: "ShogiCoachCoreTests", dependencies: ["ShogiCoachCore"])
    ]
)
