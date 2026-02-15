// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BuddyQuestKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BuddyQuestKit",
            targets: ["BuddyQuestKit"]
        )
    ],
    targets: [
        .target(
            name: "BuddyQuestKit",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "BuddyQuestKitTests",
            dependencies: ["BuddyQuestKit"],
            path: "Tests"
        )
    ]
)
