// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peeksh",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Peeksh", targets: ["Peeksh"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0")
    ],
    targets: [
        .target(name: "PeekshCore"),
        .executableTarget(
            name: "Peeksh",
            dependencies: ["PeekshCore", .product(name: "SwiftTerm", package: "SwiftTerm")],
            resources: [.copy("Resources/ShellIntegration")]
        ),
        .testTarget(name: "PeekshCoreTests", dependencies: ["PeekshCore"]),
        .testTarget(name: "PeekshTests", dependencies: ["Peeksh"])
    ]
)
