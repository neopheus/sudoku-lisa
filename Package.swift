// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SudokuLisa",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "SudokuCore", targets: ["SudokuCore"])],
    targets: [.target(name: "SudokuCore"), .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"])]
)
