import CryptoKit
import Foundation
import Security

/// Operating-system ceremonies for hosts that already own a JavaScript runtime.
public final class ClerkJSPlatformCapabilities: @unchecked Sendable {
  #if !os(watchOS)
  private let passkeys = ClerkJSPasskeyCeremony()
  private let apple = ClerkJSAppleCeremony()
  private let biometrics = ClerkJSBiometricCeremony()
  private let appAttest = ClerkJSAppAttestCeremony()
  #endif

  public init() {}

  public func perform(_ action: String, payload: String) async throws -> String {
    if action == "randomString" {
      let count = try JSONDecoder().decode(Int.self, from: Data(payload.utf8))
      guard (1 ... 1024).contains(count) else { throw ClerkJSError(kind: .runtime, message: "Invalid random byte count") }
      var bytes = [UInt8](repeating: 0, count: count)
      guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw ClerkJSError(kind: .runtime, message: "Secure random generation failed") }
      return try String(decoding: JSONEncoder().encode(Self.base64URL(Data(bytes))), as: UTF8.self)
    }
    if action == "codeChallenge" {
      let verifier = try JSONDecoder().decode(String.self, from: Data(payload.utf8))
      return try String(decoding: JSONEncoder().encode(Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))), as: UTF8.self)
    }
    #if !os(watchOS)
    switch action {
    case "createPublicCredentials": return try await passkeys.create(payload: payload).get()
    case "getPublicCredentials": return try await passkeys.get(payload: payload).get()
    case "startAppleAuthentication": return try await apple.start(payload: payload).get().json
    case "biometricPresence": return try await biometrics.presence(payload: payload).get().json
    case "promptBiometrics": return try await biometrics.prompt(payload: payload).get().json
    case "prepareDeviceAttestation": return try await appAttest.attest(payload: payload).get().json
    case "prepareDeviceAssertion": return try await appAttest.assert(payload: payload).get().json
    default: break
    }
    #endif
    throw ClerkJSError(kind: .runtime, message: "Unsupported native capability: \(action)")
  }

  private static func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }

  public static func errorJSON(_ error: any Error) -> Data {
    if let error = error as? ClerkJSNativeCapabilityError, let data = try? JSONEncoder().encode(error) { return data }
    #if !os(watchOS)
    if let error = error as? ClerkJSPasskeyError { return Data(error.json.utf8) }
    if let error = error as? ClerkJSAppleError { return Data(error.json.utf8) }
    if let error = error as? ClerkJSBiometricError { return Data(error.json.utf8) }
    if let error = error as? ClerkJSAppAttestError { return Data(error.json.utf8) }
    #endif
    return (try? JSONEncoder().encode(["code": "native_capability_failed", "message": error.localizedDescription])) ?? Data("{}".utf8)
  }

  public func cancel() {
    #if !os(watchOS)
    passkeys.cancel()
    apple.cancel()
    biometrics.cancel()
    appAttest.cancel()
    #endif
  }
}
