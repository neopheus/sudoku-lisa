// Lossless runtime packaging; keep the editable JSON out of the app target.
// Usage: swift scripts/mascot/compress_rig.swift input.json output.lzfse
import Foundation
guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: compress_rig.swift input.json output.lzfse")
}
let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let compressed = try (original as NSData).compressed(using: .lzfse)
let restored = try compressed.decompressed(using: .lzfse) as Data
precondition(restored == original)
try compressed.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
print("\(original.count) -> \(compressed.length) bytes; exact round-trip verified")
