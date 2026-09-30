// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VladLander",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "VladLander", targets: ["VladLander"])],
    targets: [
        .target(name: "FlightCore"),
        .executableTarget(name: "VladLander", dependencies: ["FlightCore"]),
        .testTarget(name: "FlightCoreTests", dependencies: ["FlightCore"]),
        .testTarget(name: "LanderTests", dependencies: ["VladLander", "FlightCore"])
    ]
)
