//
//  BiometricCredentials.swift
//  Clerk
//

import Foundation

/// The main entry point for biometric credential operations.
@MainActor
public struct BiometricCredentials {
  private let biometricCredentialService: BiometricCredentialServiceProtocol
  private let signInService: SignInServiceProtocol
  private let keyManager: any BiometricCredentialKeyManagerProtocol
  private let credentialStore: any BiometricCredentialLocalStoreProtocol
  private let appIdentifierProvider: @MainActor @Sendable () -> String?

  init(
    biometricCredentialService: BiometricCredentialServiceProtocol,
    signInService: SignInServiceProtocol,
    keyManager: any BiometricCredentialKeyManagerProtocol,
    credentialStore: any BiometricCredentialLocalStoreProtocol,
    appIdentifierProvider: @escaping @MainActor @Sendable () -> String? = {
      Bundle.main.bundleIdentifier
    }
  ) {
    self.biometricCredentialService = biometricCredentialService
    self.signInService = signInService
    self.keyManager = keyManager
    self.credentialStore = credentialStore
    self.appIdentifierProvider = appIdentifierProvider
  }

  /// Lists active biometric credentials for the signed-in user.
  public func list() async throws -> [BiometricCredential] {
    try await biometricCredentialService.list()
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
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint, userID: nil) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  package func currentUserAvailability() async throws -> BiometricCredentialAvailability {
    guard let userID = Clerk.shared.user?.id else {
      return .unavailable(.noLocalCredential)
    }

    switch try await selectedLocalCredential(id: nil, identifierHint: nil, userID: userID) {
    case .available:
      return .available
    case let .unavailable(reason):
      return .unavailable(reason)
    }
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
    guard let session = Clerk.shared.session,
          session.status.allowsBiometricCredentialEnrollment
    else {
      throw ClerkClientError(message: "Unable to enroll a biometric credential without an active or pending Clerk session.")
    }
    try ensureBiometricCredentialFeatureEnabled()

    guard let appIdentifier = appIdentifierProvider() else {
      throw ClerkClientError(message: "Unable to enroll a biometric credential without a bundle identifier.")
    }
    guard let userID = session.user?.id else {
      throw ClerkClientError(message: "Unable to enroll a biometric credential without a user for the current session.")
    }

    let localKey = try keyManager.createKey(policy: policy)
    do {
      let challenge = try await biometricCredentialService.prepareEnrollment(
        sessionId: session.id,
        params: .init(
          appIdentifier: appIdentifier,
          name: name,
          publicKeyJWK: localKey.publicKeyJWK
        )
      )
      let signature = try keyManager.sign(
        clientData: challenge.clientData,
        localKeyId: localKey.localKeyId,
        localizedReason: reason ?? "Use biometrics to enroll this device."
      )
      let biometricCredential = try await biometricCredentialService.attemptEnrollment(
        sessionId: session.id,
        params: .init(
          appIdentifier: appIdentifier,
          name: name,
          publicKeyJWK: localKey.publicKeyJWK,
          clientData: signature.clientData,
          signature: signature.signature
        )
      )
      try await saveLocalCredential(
        biometricCredential: biometricCredential,
        localKey: localKey,
        sessionId: session.id,
        userID: userID,
        identifierHint: identifierHint
      )
      removeOtherLocalCredentialsForCurrentApp(keeping: biometricCredential)
      return biometricCredential
    } catch {
      try? keyManager.deleteKey(localKeyId: localKey.localKeyId)
      throw error
    }
  }

  /// Revokes a biometric credential for the signed-in user.
  ///
  /// After server revocation succeeds, the SDK attempts to remove any matching local private key
  /// and metadata. A local cleanup failure does not affect the returned revoked credential.
  @discardableResult
  public func revoke(id: String) async throws -> BiometricCredential {
    let biometricCredential = try await biometricCredentialService.revoke(
      biometricCredentialId: id,
      sessionId: Clerk.shared.session?.id
    )
    do {
      if let localCredential = try credentialStore.credential(id: id) {
        try deleteLocalCredential(localCredential)
      }
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to delete local biometric credential after server revocation. This is non-critical."
      )
    }
    return biometricCredential
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
    guard Clerk.shared.session?.status.allowsBiometricCredentialEnrollment == true else {
      throw ClerkClientError(message: "Unable to revoke a biometric credential without an active or pending Clerk session.")
    }
    guard let userID = Clerk.shared.user?.id else {
      return nil
    }

    switch try await selectedLocalCredential(id: nil, identifierHint: nil, userID: userID) {
    case let .available(localCredential):
      return try await revoke(id: localCredential.id)
    case .unavailable:
      return nil
    }
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
    let localCredential: BiometricCredentialLocalRecord
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint, userID: nil) {
    case let .available(credential):
      localCredential = credential
    case .unavailable:
      throw ClerkClientError(
        message: "Biometric sign-in is unavailable."
      )
    }
    let biometricCredentialId = localCredential.id

    let signIn: SignIn
    do {
      signIn = try await signInService.create(params: .init(
        strategy: .biometricCredential,
        biometricCredentialId: biometricCredentialId
      ))
    } catch {
      throw handleBiometricSignInError(error, localCredential: localCredential)
    }

    let challenge = try biometricCredentialChallenge(from: signIn)
    let signature = try keyManager.sign(
      clientData: challenge.clientData,
      localKeyId: localCredential.localKeyId,
      localizedReason: reason ?? "Use biometrics to sign in."
    )

    do {
      return try await signInService.attemptFirstFactor(
        signInId: signIn.id,
        params: .init(
          strategy: .biometricCredential,
          biometricCredentialId: biometricCredentialId,
          clientData: signature.clientData,
          signature: signature.signature,
          algorithm: signature.algorithm
        )
      )
    } catch {
      throw handleBiometricSignInError(error, localCredential: localCredential)
    }
  }
}

extension BiometricCredentials {
  package func validateLocalCredentialIfPossible(
    id: String? = nil,
    identifierHint: String? = nil
  ) async -> BiometricCredentialValidationResult {
    if biometricCredentialFeatureUnavailableReason == .environmentUnavailable {
      return .inconclusive
    }

    let localCredentials: [BiometricCredentialLocalRecord]
    do {
      switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: nil) {
      case let .available(credentials):
        localCredentials = credentials
      case let .unavailable(reason):
        return .invalid(reason)
      }
    } catch {
      return .inconclusive
    }

    guard Clerk.shared.client != nil else {
      return .inconclusive
    }

    var firstUnavailableReason: BiometricCredentialAvailability.UnavailableReason?

    for localCredential in localCredentials {
      do {
        let validation = try await biometricCredentialService.validateSignInCredential(biometricCredentialId: localCredential.id)
        guard validation.valid else {
          try? deleteLocalCredential(localCredential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }
        return .valid
      } catch {
        if error.isMissingBiometricCredential {
          try? deleteLocalCredential(localCredential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }
        if let unavailableReason = error.biometricCredentialValidationUnavailableReason {
          return .invalid(unavailableReason)
        }
        return .inconclusive
      }
    }

    return .invalid(firstUnavailableReason ?? .serverCredentialMissing)
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

  private func ensureBiometricCredentialFeatureEnabled() throws {
    guard let reason = biometricCredentialFeatureUnavailableReason else {
      return
    }

    switch reason {
    case .environmentUnavailable:
      throw ClerkClientError(message: "Unable to use biometric sign-in before the Clerk environment is loaded.")
    case .nativeAPIDisabled:
      throw ClerkClientError(message: "Unable to use biometric sign-in because Native API is disabled.")
    case .featureDisabled:
      throw ClerkClientError(message: "Unable to use biometric sign-in because it is disabled.")
    default:
      throw ClerkClientError(message: "Biometric sign-in is unavailable.")
    }
  }

  private enum LocalCredentialResult<Value> {
    case available(Value)
    case unavailable(BiometricCredentialAvailability.UnavailableReason)
  }

  private func selectedLocalCredential(
    id: String?,
    identifierHint: String?,
    userID: String?
  ) async throws -> LocalCredentialResult<BiometricCredentialLocalRecord> {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: userID) {
    case let .available(supportedCredentials):
      guard Clerk.shared.session?.status == .active else {
        return .available(supportedCredentials[0])
      }

      guard let activeUserID = Clerk.shared.session?.user?.id else {
        return .available(supportedCredentials[0])
      }

      var biometricCredentials: [BiometricCredential]?
      var firstUnavailableReason: BiometricCredentialAvailability.UnavailableReason?
      let activeUserCredentials = supportedCredentials.filter { $0.userID == activeUserID }
      guard !activeUserCredentials.isEmpty else {
        return .unavailable(.noLocalCredential)
      }

      for credential in activeUserCredentials {
        let activeUserBiometricCredentials: [BiometricCredential]
        if let biometricCredentials {
          activeUserBiometricCredentials = biometricCredentials
        } else {
          let fetchedBiometricCredentials = try await biometricCredentialService.list()
          biometricCredentials = fetchedBiometricCredentials
          activeUserBiometricCredentials = fetchedBiometricCredentials
        }

        guard let biometricCredential = activeUserBiometricCredentials.first(where: { $0.id == credential.id }) else {
          try deleteLocalCredential(credential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }

        guard biometricCredential.status == .active else {
          try deleteLocalCredential(credential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialRevoked
          continue
        }

        return .available(credential)
      }

      return .unavailable(firstUnavailableReason ?? .serverCredentialMissing)
    case let .unavailable(reason):
      return .unavailable(reason)
    }
  }

  private func localCredentialCandidates(
    id: String?,
    identifierHint: String?,
    userID: String?
  ) throws -> LocalCredentialResult<[BiometricCredentialLocalRecord]> {
    if let unavailableReason = biometricCredentialFeatureUnavailableReason {
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

  private func saveLocalCredential(
    biometricCredential: BiometricCredential,
    localKey: BiometricCredentialLocalKey,
    sessionId: String,
    userID: String,
    identifierHint: String?
  ) async throws {
    do {
      try credentialStore.save(
        .init(
          biometricCredential: biometricCredential,
          localKey: localKey,
          userID: userID,
          identifierHint: identifierHint
        ),
        deleteReplacedLocalKey: { localKeyId in
          try keyManager.deleteKey(localKeyId: localKeyId)
        }
      )
    } catch {
      _ = try? await biometricCredentialService.revoke(
        biometricCredentialId: biometricCredential.id,
        sessionId: sessionId
      )
      throw error
    }
  }

  private func removeOtherLocalCredentialsForCurrentApp(keeping biometricCredential: BiometricCredential) {
    let credentialsToReplace: [BiometricCredentialLocalRecord]
    do {
      // The backend replaces active credentials by installation and app identifier, even across users.
      credentialsToReplace = try storedLocalCredentialsForCurrentApp().filter { $0.id != biometricCredential.id }
    } catch {
      ClerkLogger.warning(
        "Failed to load replaced biometric credentials for local cleanup. Error: \(error)"
      )
      return
    }

    for credential in credentialsToReplace {
      do {
        try deleteLocalCredential(credential)
      } catch {
        ClerkLogger.warning(
          "Failed to remove replaced biometric credential locally. Error: \(error)"
        )
      }
    }
  }

  private func biometricCredentialChallenge(from signIn: SignIn) throws -> BiometricCredentialChallenge {
    guard let biometricCredentialChallenge = signIn.firstFactorVerification?.biometricCredentialChallenge else {
      throw ClerkClientError(message: "Biometric sign-in did not return a challenge.")
    }
    return biometricCredentialChallenge
  }

  private func handleBiometricSignInError(
    _ error: Error,
    localCredential: BiometricCredentialLocalRecord
  ) -> Error {
    guard error.isMissingBiometricCredential else {
      return error
    }

    try? deleteLocalCredential(localCredential)
    return ClerkClientError(message: "This device is no longer trusted. Sign in another way to enroll it again.")
  }
}

extension Error {
  fileprivate var isMissingBiometricCredential: Bool {
    guard let error = self as? ClerkAPIError else {
      return false
    }

    return BiometricCredentialAPIError.missingCredentialCodes.contains(error.code) &&
      error.meta?["param_name"]?.stringValue == BiometricCredentialAPIError.biometricCredentialIDParamName
  }

  fileprivate var biometricCredentialValidationUnavailableReason: BiometricCredentialAvailability.UnavailableReason? {
    guard let error = self as? ClerkAPIError else {
      return nil
    }

    switch error.code {
    case BiometricCredentialAPIError.nativeAPIDisabledCode:
      return .nativeAPIDisabled
    case BiometricCredentialAPIError.featureNotEnabledCode:
      return .featureDisabled
    default:
      return nil
    }
  }
}

private enum BiometricCredentialAPIError {
  static let formResourceNotFoundCode = "form_resource_not_found"
  static let biometricCredentialNotRegisteredCode = "trusted_device_not_registered"
  static let biometricCredentialIDParamName = "trusted_device_id"
  static let nativeAPIDisabledCode = "native_api_disabled"
  static let featureNotEnabledCode = "feature_not_enabled"

  static let missingCredentialCodes = [
    formResourceNotFoundCode,
    biometricCredentialNotRegisteredCode,
  ]
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
