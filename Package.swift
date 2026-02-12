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
            dependencies: [],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "YesChefCoreTests",
            dependencies: ["YesChefCore"]
        )
    ]
)
