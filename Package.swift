// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YesChef",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "YesChefCore", targets: ["YesChefCore"])
    ],
    targets: [
        .target(
            name: "YesChefCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "YesChefCoreTests",
            dependencies: ["YesChefCore"]
        )
    ]
)
