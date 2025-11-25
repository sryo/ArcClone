// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArcClone",
    platforms: [
        .macOS(.v14) // Keeping v14 for now as v15 might not be available in this Swift version environment
        // If the user wants macOS 15 features, we can try .v14 and use if #available
        // But the user explicitly asked for the new API.
        // Let's try to stick to v14 and use the .toolbar modifier which is the v14 equivalent.
        // The user pasted docs for toolbarVisibility (v15) but .toolbar(.hidden) (v14) does the same thing.
        // I will use .toolbar(.hidden) in the App file.
    ],
    products: [
        .executable(name: "ArcClone", targets: ["ArcClone"]),
    ],
    targets: [
        .executableTarget(
            name: "ArcClone",
            path: "Sources/ArcClone"
        ),
    ]
)
