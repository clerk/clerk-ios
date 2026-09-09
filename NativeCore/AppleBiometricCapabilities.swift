import Foundation

@MainActor public final class AppleBiometricCapabilities {
  private let appIdentifier: String
  private let publishableKey: String
  private let credentials: any CredentialStorage
  private let cleanup: any CredentialStorage
  private let keys = AppleBiometricKeyManager()

  public init(publishableKey: String, appIdentifier: String = Bundle.main.bundleIdentifier ?? "", credentials: any CredentialStorage, cleanup: any CredentialStorage) {
    self.publishableKey = publishableKey
    self.appIdentifier = appIdentifier
    self.credentials = credentials
    self.cleanup = cleanup
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    func string(_ key: String) throws -> String {
      try (args[key] ?? .undefined).string()
    }
    func policy() throws -> AppleBiometricKeyPolicy {
      guard let policy = try AppleBiometricKeyPolicy(rawValue: string("policy")) else { throw CoreError.invalidValue }
      return policy
    }
    do {
      switch capability {
      case "biometrics.appIdentifier": return .string(appIdentifier)
      case "biometrics.storage.read", "biometrics.storage.write":
        guard args["scope"] == .string(publishableKey) else { throw CoreError(code: "invalid_storage_scope") }
        let storage: any CredentialStorage
        switch try string("key") {
        case "credentials": storage = credentials
        case "cleanup": storage = cleanup
        default: throw CoreError(code: "invalid_storage_scope")
        }
        if capability == "biometrics.storage.read" { return try await storage.read().map(JSONValue.string) ?? .null }
        try await storage.write(string("value"))
        return .null
      case "biometrics.supports": return try .bool(keys.isSupported(policy: policy()))
      case "biometrics.hasKey": return try .bool(keys.hasKey(localKeyId: string("localKeyId")))
      case "biometrics.createKey":
        let key = try keys.createKey(policy: policy())
        return .object(["localKeyId": .string(key.localKeyId), "publicKeyJwk": .string(key.publicKeyJWK)])
      case "biometrics.sign":
        let signature = try keys.sign(clientData: string("clientData"), localKeyId: string("localKeyId"), localizedReason: string("reason"))
        return .object(["clientData": .string(signature.clientData), "signature": .string(signature.signature), "algorithm": .string(signature.algorithm)])
      case "biometrics.deleteKey":
        try keys.deleteKey(localKeyId: string("localKeyId"))
        return .null
      default: throw CoreError(code: "capability_unavailable")
      }
    } catch let error as AppleBiometricKeyError {
      let code = switch error {
      case .biometricAuthenticationCanceled: "user_cancelled"
      case .biometricAuthenticationUnavailable: "biometric_authentication_unavailable"
      case .biometricAuthenticationFailed: "biometric_authentication_failed"
      case .keyNotFound: "key_not_found"
      case .unsupportedPlatform: "capability_unavailable:biometrics"
      default: "biometric_key_error"
      }
      throw CoreError(code: code, message: error.localizedDescription)
    }
  }
}
