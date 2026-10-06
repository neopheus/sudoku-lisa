// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SudokuLisa",
    defaultLocalization: "fr",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "SudokuCore", targets: ["SudokuCore"])],
    targets: [.target(name: "SudokuCore", resources: [.process("Resources")]), .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"])]
)
