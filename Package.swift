// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-timeline",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [.library(name: "Timeline", targets: ["Timeline"])],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-bezier.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-exponential.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-point.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-rational.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-spring.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-trigonometry.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Timeline",
            dependencies: [
                .product(name: "Bezier", package: "swift-bezier"),
                .product(name: "Cardinal", package: "swift-cardinal"),
                .product(name: "Exponential", package: "swift-exponential"),
                .product(name: "Point", package: "swift-point"),
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "Spring", package: "swift-spring"),
                .product(name: "Trigonometry", package: "swift-trigonometry"),
            ]
        ),
        .testTarget(
            name: "Timeline Tests",
            dependencies: [
                .target(name: "Timeline")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
