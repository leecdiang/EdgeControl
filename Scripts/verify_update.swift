import CryptoKit
import Foundation

// Verify against the public key embedded in the packaged application, not just
// whichever signing identity happens to be selected in the user's Keychain.
let args = CommandLine.arguments
guard args.count == 4,
      let publicKey = Data(base64Encoded: args[2]),
      let signature = Data(base64Encoded: args[3]) else {
    fatalError("Usage: verify_update.swift archive public-key signature")
}
let archive = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Update signature does not match the application's public key")
}
print("Sparkle Ed25519 signature verified against embedded public key")
