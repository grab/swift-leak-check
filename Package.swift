// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LeakCheckFramework",
    products: [
      .library(name: "LeakCheckFramework", targets: ["LeakCheckFramework"]),
      .executable(name: "Sample", targets: ["Sample"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
      .package(url: "https://github.com/apple/swift-syntax", .exact("0.50000.0")),
      .package(url: "https://github.com/jpsim/SourceKitten", from: "0.20.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
          name: "Sample",
          dependencies: [
            "LeakCheckFramework"
          ]
        ),
        .target(
          name: "LeakCheckFramework",
          dependencies: [
            "SourceKittenFramework",
            "SwiftSyntax"
          ]
        ),
        .testTarget(
          name: "LeakCheckFrameworkTests",
          dependencies: ["LeakCheckFramework"]
        )
    ]
)
