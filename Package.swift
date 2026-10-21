// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "term-cut",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TermCut", targets: ["TermCut"])],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0")
    ],
    targets: [
        .target(name: "TermCutCore"),
        .executableTarget(
            name: "TermCut",
            dependencies: ["TermCutCore", .product(name: "SwiftTerm", package: "SwiftTerm")],
            resources: [.copy("Resources/ShellIntegration")]
        ),
        .testTarget(name: "TermCutCoreTests", dependencies: ["TermCutCore"]),
        .testTarget(name: "TermCutTests", dependencies: ["TermCut"])
    ]
)
