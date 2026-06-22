// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "keymood",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "KeyMoodCore", targets: ["KeyMoodCore"]),
    .library(name: "KeyMoodSensor", targets: ["KeyMoodSensor"]),
    .executable(name: "keymood-probe", targets: ["KeyMoodProbe"]),
    .executable(name: "keymood-menubar", targets: ["KeyMoodMenuBar"])
  ],
  targets: [
    .target(name: "KeyMoodCore"),
    .target(
      name: "KeyMoodSensor",
      dependencies: ["KeyMoodCore"],
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .executableTarget(
      name: "KeyMoodProbe",
      dependencies: ["KeyMoodCore", "KeyMoodSensor"],
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .executableTarget(
      name: "KeyMoodMenuBar",
      dependencies: ["KeyMoodCore", "KeyMoodSensor"],
      linkerSettings: [
        .linkedFramework("AppKit")
      ]
    ),
    .testTarget(
      name: "KeyMoodCoreTests",
      dependencies: ["KeyMoodCore"]
    )
  ]
)
