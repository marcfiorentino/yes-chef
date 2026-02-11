// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YesChef",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "YesChefCore", targets: ["YesChefCore"]),
        .library(name: "YesChefApp", targets: ["YesChefApp"])
    ],
    targets: [
        .target(
            name: "YesChefCore",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "YesChefApp",
            dependencies: ["YesChefCore"]
        ),
        .testTarget(
            name: "YesChefCoreTests",
            dependencies: ["YesChefCore"]
        )
    ]
)
