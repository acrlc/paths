// swift-tools-version:5.3
import PackageDescription

let package = Package(
 name: "Paths",
 products: [.library(name: "Paths", targets: ["Paths"])],
 targets: [
  .target(name: "Paths", path: "Sources"),
  .testTarget(name: "PathsTests", dependencies: ["Paths"])
 ]
)

// add OpenCombine for framewords that depend on Combine functionality
package.dependencies.append(.package(path: "~/.git/apple/swift-crypto"))
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
