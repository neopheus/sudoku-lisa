// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SudokuLisa",
    defaultLocalization: "fr",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "SudokuCore", targets: ["SudokuCore"]),
               .library(name: "PoulpiStickers", targets: ["PoulpiStickers"]),
               .library(name: "LisaInvitations", targets: ["LisaInvitations"])],
    targets: [.target(name: "SudokuCore", resources: [.process("Resources")]),
              .target(name: "PoulpiStickers", resources: [.process("Resources")]),
              .target(name: "LisaInvitations"),
              .testTarget(name: "LisaInvitationsTests", dependencies: ["LisaInvitations"]),
              .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"])]
)
