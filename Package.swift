// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Copyright 2019 Grabtaxi Holdings PTE LTE (GRAB), All rights reserved.
//  Use of this source code is governed by an MIT-style license that can be found in the LICENSE file
//

import PackageDescription

let package = Package(
    name: "SwiftLeakCheck",
    products: [
      .library(name: "SwiftLeakCheck", targets: ["SwiftLeakCheck"]),
      .executable(name: "SwiftLeakChecker", targets: ["SwiftLeakChecker"])
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
          name: "SwiftLeakChecker",
          dependencies: [
            "SwiftLeakCheck"
          ]
        ),
        .target(
          name: "SwiftLeakCheck",
          dependencies: [
            "SourceKittenFramework",
            "SwiftSyntax"
          ]
        ),
        .testTarget(
          name: "SwiftLeakCheckTests",
          dependencies: ["SwiftLeakCheck"]
        )
    ]
)
