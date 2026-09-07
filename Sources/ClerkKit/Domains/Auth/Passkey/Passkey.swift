import Foundation

extension Passkey {
  var nonceJSON: JSON? {
    verification?.nonce?.toJSON()
  }

  var challenge: Data? {
    let challengeString = nonceJSON?.challenge?.stringValue
    return challengeString?.dataFromBase64URL()
  }

  var username: String? {
    nonceJSON?.user?.name?.stringValue
  }

  var userId: Data? {
    nonceJSON?.user?.id?.stringValue?.base64URLFromBase64String().dataFromBase64URL()
  }

  var relyingPartyIdentifier: String? {
    guard let identifier = nonceJSON?.rp?.id?.stringValue, !identifier.isEmpty else {
      return nil
    }
    return identifier
  }
}

extension Passkey {
  @MainActor
  private var passkeyService: any PasskeyServiceProtocol {
    Clerk.shared.dependencies.passkeyService
  }

  /// Attempts to verify the passkey with a credential.
  @discardableResult @MainActor
  public func attemptVerification(credential: String) async throws -> Passkey {
    try await passkeyService.attemptVerification(passkeyId: id, credential: credential)
  }
}
