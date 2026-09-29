// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VladPhysics",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "VladPhysics", targets: ["VladPhysics"])],
    targets: [
        .target(name: "FlightCore"),
        .executableTarget(name: "VladPhysics", dependencies: ["FlightCore"]),
        .testTarget(name: "FlightCoreTests", dependencies: ["FlightCore"]),
        .testTarget(name: "GameModelTests", dependencies: ["VladPhysics", "FlightCore"])
    ]
)
