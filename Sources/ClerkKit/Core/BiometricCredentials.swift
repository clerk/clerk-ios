//
//  BiometricCredentials.swift
//  Clerk
//

import ClerkSnapshots
import Foundation

/// The main entry point for biometric credential operations.
@MainActor
public struct BiometricCredentials {
  private let keyManager: any BiometricCredentialKeyManagerProtocol
  private let credentialStore: any BiometricCredentialLocalStoreProtocol
  private let appIdentifierProvider: @MainActor @Sendable () -> String?

  init(
    keyManager: any BiometricCredentialKeyManagerProtocol,
    credentialStore: any BiometricCredentialLocalStoreProtocol,
    appIdentifierProvider: @escaping @MainActor @Sendable () -> String? = {
      Bundle.main.bundleIdentifier
    }
  ) {
    self.keyManager = keyManager
    self.credentialStore = credentialStore
    self.appIdentifierProvider = appIdentifierProvider
  }

  /// Lists active biometric credentials for the signed-in user.
  public func list() async throws -> [BiometricCredential] {
    try await Clerk.js(.clerk, JSRawCall("listNativeBiometricCredentials"), as: [BiometricCredential].self)
  }

  /// Returns local biometric sign-in availability.
  ///
  /// When a Clerk session is active, this also reconciles the local credential with the server.
  /// Without an active session, this reports whether the local biometric-gated credential can
  /// be used to start biometric sign-in.
  public func availability(
    id: String? = nil,
    identifierHint: String? = nil
  ) async throws -> BiometricCredentialAvailability {
    try await sharedAvailability(id: id, identifierHint: identifierHint)
  }

  package func currentUserAvailability() async throws -> BiometricCredentialAvailability {
    try await sharedAvailability(currentUser: true)
  }

  /// Returns local biometric sign-in availability without reconciling with the server.
  package func localAvailability(
    id: String? = nil,
    identifierHint: String? = nil
  ) throws -> BiometricCredentialAvailability {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: nil) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  package func currentUserLocalAvailability() throws -> BiometricCredentialAvailability {
    guard let userID = Clerk.shared.user?.id else {
      return .unavailable(.noLocalCredential)
    }

    switch try localCredentialCandidates(id: nil, identifierHint: nil, userID: userID) {
    case .available:
      return .available
    case let .unavailable(reason):
      return .unavailable(reason)
    }
  }

  /// Enrolls the current app installation as a biometric credential.
  ///
  /// This requires an active or pending Clerk session. The generated private key stays on the device.
  /// - Parameters:
  ///   - name: A human-readable name stored with the biometric credential.
  ///   - identifierHint: A local-only user identifier hint for selecting this credential later.
  ///   - reason: The reason shown in the system biometric prompt.
  ///   - policy: The local authentication policy used to protect the generated private key.
  ///     Defaults to requiring a biometric from the currently enrolled set.
  @discardableResult
  public func enroll(
    name: String? = nil,
    identifierHint: String? = nil,
    reason: String? = nil,
    policy: BiometricCredentialPolicy = .biometryCurrentSet
  ) async throws -> BiometricCredential {
    try await Clerk.js(.clerk, JSRawCall("enrollNativeBiometricCredential", .object([
      "name": name.map(JSONValue.string) ?? .null,
      "identifierHint": identifierHint.map(JSONValue.string) ?? .null,
      "reason": reason.map(JSONValue.string) ?? .null,
      "policy": .string(policy.rawValue),
    ])), as: BiometricCredential.self)
  }

  /// Revokes a biometric credential for the signed-in user.
  ///
  /// After server revocation succeeds, the SDK attempts to remove any matching local private key
  /// and metadata. A local cleanup failure does not affect the returned revoked credential.
  @discardableResult
  public func revoke(id: String) async throws -> BiometricCredential {
    try await Clerk.js(.clerk, JSRawCall("revokeNativeBiometricCredentialAndForget", .string(id)), as: BiometricCredential.self)
  }

  /// Revokes the biometric credential for the current app installation and signed-in user.
  ///
  /// Call this method before signing out because it requires an active or pending Clerk session.
  /// When a credential is available, it is revoked on the server and the SDK attempts to remove
  /// its local private key and metadata. A local cleanup failure does not affect the returned
  /// revoked credential.
  ///
  /// - Returns: The revoked biometric credential, or `nil` when this app installation has no
  ///   available local credential for the current user.
  @discardableResult
  public func revokeCurrentDeviceCredential() async throws -> BiometricCredential? {
    try await Clerk.js(.clerk, JSRawCall("revokeCurrentNativeBiometricCredential"), as: BiometricCredential?.self)
  }

  @discardableResult
  package func forgetLocalCredentials(deletedUserID: String) throws -> Int {
    try forgetLocalCredentialsForCurrentApp(userID: deletedUserID)
  }

  private func forgetLocalCredentialsForCurrentApp(userID: String) throws -> Int {
    let credentials = try storedLocalCredentialsForCurrentApp().filter { $0.userID == userID }

    for credential in credentials {
      try deleteLocalCredential(credential)
    }

    return credentials.count
  }

  /// Signs in with a locally enrolled biometric credential.
  ///
  /// - Parameters:
  ///   - id: The biometric credential ID to use. When omitted, the available local credential is used. If
  ///     legacy local state contains multiple credentials for this app installation, the newest supported
  ///     credential is used.
  ///   - identifierHint: A local-only user identifier hint used to choose a matching credential.
  ///   - reason: The reason shown in the system biometric prompt.
  @discardableResult
  package func signIn(
    id: String? = nil,
    identifierHint: String? = nil,
    reason: String? = nil
  ) async throws -> SignIn {
    try await Clerk.js(.clerk, JSRawCall("signInWithNativeBiometricCredential", .object([
      "id": id.map(JSONValue.string) ?? .null,
      "identifierHint": identifierHint.map(JSONValue.string) ?? .null,
      "reason": reason.map(JSONValue.string) ?? .null,
    ])), as: SignIn.self)
  }
}

extension BiometricCredentials {
  package func validateLocalCredentialIfPossible(
    id: String? = nil,
    identifierHint: String? = nil
  ) async -> BiometricCredentialValidationResult {
    do {
      let result = try await Clerk.js(.clerk, JSRawCall("validateNativeLocalBiometricCredential", .object([
        "id": id.map(JSONValue.string) ?? .null,
        "identifierHint": identifierHint.map(JSONValue.string) ?? .null,
      ])), as: NativeBiometricAvailability.self)
      if result.status == "valid" { return .valid }
      if result.status == "invalid", let reason = result.reason { return .invalid(reason) }
      return .inconclusive
    } catch {
      return .inconclusive
    }
  }

  private var biometricCredentialFeatureUnavailableReason: BiometricCredentialAvailability.UnavailableReason? {
    guard let nativeSettings = Clerk.shared.environment?.authConfig.nativeSettings else {
      return .environmentUnavailable
    }
    guard nativeSettings.apiEnabled else {
      return .nativeAPIDisabled
    }
    guard nativeSettings.biometricSignInEnabled else {
      return .featureDisabled
    }
    return nil
  }

  private enum LocalCredentialResult<Value> {
    case available(Value)
    case unavailable(BiometricCredentialAvailability.UnavailableReason)
  }

  private func localCredentialCandidates(
    id: String?,
    identifierHint: String?,
    userID: String?,
    checkFeature: Bool = true
  ) throws -> LocalCredentialResult<[BiometricCredentialLocalRecord]> {
    if checkFeature, let unavailableReason = biometricCredentialFeatureUnavailableReason {
      return .unavailable(unavailableReason)
    }

    let localCredentials = try candidateLocalCredentials(id: id, identifierHint: identifierHint, userID: userID)
    guard !localCredentials.isEmpty else {
      return .unavailable(.noLocalCredential)
    }

    let credentialsWithKeys = try localCredentialsWithExistingKeys(from: localCredentials)
    guard !credentialsWithKeys.isEmpty else {
      return .unavailable(.localKeyMissing)
    }

    let supportedCredentials = credentialsWithKeys.filter { keyManager.isSupported(policy: $0.policy) }
    guard !supportedCredentials.isEmpty else {
      return .unavailable(.biometricAuthenticationUnavailable)
    }

    return .available(supportedCredentials)
  }

  private func candidateLocalCredentials(
    id: String?,
    identifierHint: String?,
    userID: String?
  ) throws -> [BiometricCredentialLocalRecord] {
    var credentials = try storedLocalCredentialsForCurrentApp()
    if let id {
      credentials = credentials.filter { $0.id == id }
    }
    if let userID {
      credentials = credentials.filter { $0.userID == userID }
    } else {
      credentials = credentials.filter { $0.matches(identifierHint: identifierHint) }
    }
    return credentials.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt > rhs.createdAt
      }
      if lhs.updatedAt != rhs.updatedAt {
        return lhs.updatedAt > rhs.updatedAt
      }
      return lhs.id > rhs.id
    }
  }

  private func storedLocalCredentialsForCurrentApp() throws -> [BiometricCredentialLocalRecord] {
    guard let appIdentifier = appIdentifierProvider() else {
      return []
    }

    return try credentialStore.all(appIdentifier: appIdentifier)
  }

  private func localCredentialsWithExistingKeys(
    from credentials: [BiometricCredentialLocalRecord]
  ) throws -> [BiometricCredentialLocalRecord] {
    var credentialsWithKeys: [BiometricCredentialLocalRecord] = []

    for credential in credentials {
      if try localKeyExists(for: credential) {
        credentialsWithKeys.append(credential)
      } else {
        try deleteLocalCredential(credential)
      }
    }

    return credentialsWithKeys
  }

  private func localKeyExists(for credential: BiometricCredentialLocalRecord) throws -> Bool {
    do {
      return try keyManager.hasKey(localKeyId: credential.localKeyId)
    } catch let error as BiometricCredentialKeyManagerError where error == .keyNotFound {
      return false
    }
  }

  private func deleteLocalCredential(_ credential: BiometricCredentialLocalRecord) throws {
    try keyManager.deleteKey(localKeyId: credential.localKeyId)
    try credentialStore.delete(id: credential.id)
  }
}

extension Session.SessionStatus {
  package var allowsBiometricCredentialEnrollment: Bool {
    switch self {
    case .active, .pending:
      true
    default:
      false
    }
  }
}

private struct NativeBiometricAvailability: Decodable {
  let status: String?
  let reason: BiometricCredentialAvailability.UnavailableReason?
}

extension BiometricCredentials {
  private func sharedAvailability(
    id: String? = nil,
    identifierHint: String? = nil,
    currentUser: Bool = false
  ) async throws -> BiometricCredentialAvailability {
    let result = try await Clerk.js(.clerk, JSRawCall("nativeBiometricAvailability", .object([
      "id": id.map(JSONValue.string) ?? .null,
      "identifierHint": identifierHint.map(JSONValue.string) ?? .null,
      "currentUser": .bool(currentUser),
    ])), as: NativeBiometricAvailability.self)
    return result.reason.map(BiometricCredentialAvailability.unavailable) ?? .available
  }

  func deviceCapability(
    scope: ClerkRuntimeScope,
    validateIdentity: @escaping @MainActor @Sendable () throws -> Void
  ) -> BiometricDeviceCapability {
    let pendingKeys = BiometricPendingKeys()
    return { request in
      try await MainActor.run {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let request = try decoder.decode(BiometricCapabilityRequest.self, from: JSONEncoder().encode(request))
        if request.requiresCurrentIdentity {
          _ = try scope.requireCurrentClerk()
          try validateIdentity()
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        func encoded(_ value: some Encodable) throws -> JSONValue {
          try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
        }
        switch request {
        case .context:
          return .object([
            "appIdentifier": appIdentifierProvider().map(JSONValue.string) ?? .null,
            "platform": .string("ios"),
          ])
        case let .candidates(id, identifierHint, userID):
          switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: userID, checkFeature: false) {
          case let .available(credentials):
            return try .object(["credentials": encoded(credentials)])
          case let .unavailable(reason):
            return .object(["reason": .string(reason.rawValue)])
          }
        case .records:
          return try encoded(storedLocalCredentialsForCurrentApp())
        case .createKey(let policy):
          let key = try keyManager.createKey(policy: policy)
          pendingKeys.ids.insert(key.localKeyId)
          return .object([
            "localKeyId": .string(key.localKeyId),
            "publicKeyJWK": .string(key.publicKeyJWK),
            "algorithm": .string(key.algorithm.rawValue),
            "policy": .string(key.policy.rawValue),
          ])
        case let .sign(clientData, localKeyId, reason):
          let signature = try keyManager.sign(clientData: clientData, localKeyId: localKeyId, localizedReason: reason)
          try validateIdentity()
          return .object([
            "clientData": .string(signature.clientData),
            "signature": .string(signature.signature),
            "algorithm": .string(signature.algorithm.rawValue),
          ])
        case .save(let credential):
          try credentialStore.save(credential, deleteReplacedLocalKey: {
            try keyManager.deleteKey(localKeyId: $0)
          })
          pendingKeys.ids.remove(credential.localKeyId)
        case .remove(let expected):
          if try credentialStore.credential(id: expected.id) == expected {
            try deleteLocalCredential(expected)
          }
        case .removeById(let id):
          if let credential = try credentialStore.credential(id: id) {
            try deleteLocalCredential(credential)
          }
        case .deleteKey(let id):
          try keyManager.deleteKey(localKeyId: id)
          pendingKeys.ids.remove(id)
        case .dispose:
          for id in pendingKeys.ids {
            if (try? keyManager.deleteKey(localKeyId: id)) != nil { pendingKeys.ids.remove(id) }
          }
        }
        return .null
      }
    }
  }
}

@MainActor
private final class BiometricPendingKeys {
  var ids: Set<String> = []
}

typealias BiometricDeviceCapability = @Sendable (JSONValue) async throws -> JSONValue
