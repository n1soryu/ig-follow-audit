// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IGFollowAudit",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "IGFollowAudit", targets: ["IGFollowAudit"]),
    ],
    targets: [
        // Pure logic: reading the export and comparing lists. No UI, no network.
        .target(name: "FollowAuditCore"),

        // The SwiftUI Mac app.
        .executableTarget(
            name: "IGFollowAudit",
            dependencies: ["FollowAuditCore"]
        ),

        .testTarget(
            name: "FollowAuditCoreTests",
            dependencies: ["FollowAuditCore"]
        ),
    ]
)
