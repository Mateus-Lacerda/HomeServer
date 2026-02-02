// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HomeServer",
  platforms: [
    .macOS(.v26)
  ],
  targets: [
    .executableTarget(
      name: "HomeServer",
      linkerSettings: [
        // Start as a GUI app (removes the backend console window if launched from Finder later)
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker",
          "Info.plist",
        ])
      ]
    )
  ]
)
