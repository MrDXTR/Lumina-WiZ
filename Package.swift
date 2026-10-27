// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lumina",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lumina", targets: ["Lumina"])
    ],
    targets: [
        .executableTarget(
            name: "Lumina",
            path: "Sources"
        )
    ]
)
