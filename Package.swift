// swift-tools-version:5.3
import PackageDescription

let package = Package(
 name: "Paths",
 products: [
  .library(name: "Paths", targets: ["Paths"]),
  .library(name: "PathFunctions", targets: ["PathFunctions"]),
  .library(name: "PathObserver", targets: ["PathObserver"])
 ],
 targets: [
  .target(name: "Paths", path: "Sources"),
  .testTarget(name: "PathsTests", dependencies: ["Paths"]),
  .target(name: "PathFunctions", path: "Extensions/PathFunctions"),
  .target(
   name: "PathObserver", dependencies: ["Paths"],
   path: "Extensions/PathObserver"
  )
 ]
)

// add OpenCombine for framewords that depend on Combine functionality
package.dependencies.append(
 .package(url: "https://github.com/apple/swift-crypto.git", from: "3.1.0")
)
for target in package.targets {
 if target.name == "Paths" {
  target.dependencies += [
   .product(
    name: "Crypto",
    package: "swift-crypto",
    condition: .when(platforms: [.wasi, .windows, .linux])
   )
  ]
  break
 }
}
