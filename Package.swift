// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-network-inspector",
    // Mac-only by nature: nettop, netstat, networkQuality, CoreWLAN and
    // libproc exist nowhere else.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NetworkInspector", targets: ["NetworkInspector"]),
    ],
    targets: [
        .target(name: "NetworkInspector"),
        // Fixtures are real nettop, netstat, lsof and networkQuality output
        // from a Mac, with every address replaced by a documentation value.
        .testTarget(name: "NetworkInspectorTests", dependencies: ["NetworkInspector"],
                    resources: [.copy("Fixtures")]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
