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
            dependencies: ["CSQLite"],
            resources: [
                .process("Resources")
            ]
        ),
        .systemLibrary(
            name: "CSQLite"
        ),
        .testTarget(
            name: "YesChefCoreTests",
            dependencies: ["YesChefCore"]
        )
    ]
)
