//
//  TrustedDevices.swift
//  Clerk
//

import Foundation

/// The main entry point for trusted-device credential operations.
@MainActor
public struct TrustedDevices {
  private let trustedDeviceService: TrustedDeviceServiceProtocol
  private let signInService: SignInServiceProtocol
  private let keyManager: any TrustedDeviceKeyManagerProtocol
  private let credentialStore: any TrustedDeviceLocalCredentialStoreProtocol
  private let appIdentifierProvider: @MainActor @Sendable () -> String?

  init(
    trustedDeviceService: TrustedDeviceServiceProtocol,
    signInService: SignInServiceProtocol,
    keyManager: any TrustedDeviceKeyManagerProtocol,
    credentialStore: any TrustedDeviceLocalCredentialStoreProtocol,
    appIdentifierProvider: @escaping @MainActor @Sendable () -> String? = {
      Bundle.main.bundleIdentifier
    }
  ) {
    self.trustedDeviceService = trustedDeviceService
    self.signInService = signInService
    self.keyManager = keyManager
    self.credentialStore = credentialStore
    self.appIdentifierProvider = appIdentifierProvider
  }

  /// Lists active trusted-device credentials for the signed-in user.
  public func list() async throws -> [TrustedDevice] {
    try await trustedDeviceService.list()
  }

  /// Returns local trusted-device sign-in availability.
  ///
  /// When a Clerk session is active, this also reconciles the local credential with the server.
  /// Without an active session, this reports whether the local biometric-gated credential can
  /// be used to start trusted-device sign-in.
  public func availability(
    id: String? = nil,
    identifierHint: String? = nil
  ) async throws -> TrustedDeviceAvailability {
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint, userID: nil) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  package func currentUserAvailability() async throws -> TrustedDeviceAvailability {
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

  /// Returns local trusted-device sign-in availability without reconciling with the server.
  package func localAvailability(
    id: String? = nil,
    identifierHint: String? = nil
  ) throws -> TrustedDeviceAvailability {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: nil) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  package func currentUserLocalAvailability() throws -> TrustedDeviceAvailability {
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

  /// Enrolls the current app installation as a biometric trusted device.
  ///
  /// This requires an active or pending Clerk session. The generated private key stays on the device.
  /// - Parameters:
  ///   - deviceName: A human-readable device name stored with the trusted-device credential.
  ///   - identifierHint: A local-only user identifier hint for selecting this credential later.
  ///   - reason: The reason shown in the system biometric prompt.
  ///   - policy: The local authentication policy used to protect the generated private key.
  ///     Defaults to requiring biometric availability while allowing device passcode fallback during authentication.
  @discardableResult
  public func enroll(
    deviceName: String? = nil,
    identifierHint: String? = nil,
    reason: String? = nil,
    policy: TrustedDevicePolicy = .biometryOrDevicePasscode
  ) async throws -> TrustedDevice {
    guard Clerk.shared.session?.status.allowsTrustedDeviceEnrollment == true else {
      throw ClerkClientError(message: "Unable to enroll a trusted device without an active or pending Clerk session.")
    }
    try ensureTrustedDeviceFeatureEnabled()

    guard let appIdentifier = appIdentifierProvider() else {
      throw ClerkClientError(message: "Unable to enroll a trusted device without a bundle identifier.")
    }
    guard let userID = Clerk.shared.session?.user?.id else {
      throw ClerkClientError(message: "Unable to enroll a trusted device without a user for the current session.")
    }

    let localKey = try keyManager.createKey(policy: policy)
    do {
      let challenge = try await trustedDeviceService.prepareEnrollment(params: .init(
        appIdentifier: appIdentifier,
        name: deviceName,
        publicKeyJWK: localKey.publicKeyJWK
      ))
      let signature = try keyManager.sign(
        clientData: challenge.clientData,
        localKeyId: localKey.localKeyId,
        localizedReason: reason ?? "Use biometrics to enroll this device."
      )
      let trustedDevice = try await trustedDeviceService.attemptEnrollment(params: .init(
        appIdentifier: appIdentifier,
        name: deviceName,
        publicKeyJWK: localKey.publicKeyJWK,
        clientData: signature.clientData,
        signature: signature.signature
      ))
      try await saveLocalCredential(
        trustedDevice: trustedDevice,
        localKey: localKey,
        userID: userID,
        identifierHint: identifierHint
      )
      removeOtherLocalCredentialsForCurrentApp(keeping: trustedDevice)
      return trustedDevice
    } catch {
      try? keyManager.deleteKey(localKeyId: localKey.localKeyId)
      throw error
    }
  }

  /// Revokes a trusted-device credential for the signed-in user.
  @discardableResult
  public func revoke(id: String) async throws -> TrustedDevice {
    let trustedDevice = try await trustedDeviceService.revoke(trustedDeviceId: id)
    do {
      if let localCredential = try credentialStore.credential(id: id) {
        try deleteLocalCredential(localCredential)
      }
    } catch {
      ClerkLogger.logError(
        error,
        message: "Failed to delete local trusted-device credential after server revocation. This is non-critical."
      )
    }
    return trustedDevice
  }

  /// Revokes the available local trusted-device credential for the current signed-in user.
  @discardableResult
  package func revokeCurrentDeviceCredential() async throws -> TrustedDevice? {
    guard Clerk.shared.session?.status.allowsTrustedDeviceEnrollment == true else {
      throw ClerkClientError(message: "Unable to revoke a trusted device without an active or pending Clerk session.")
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

  /// Signs in with a locally enrolled biometric trusted-device credential.
  ///
  /// - Parameters:
  ///   - id: The trusted-device credential ID to use. When omitted, the available local credential is used. If
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
    let localCredential: TrustedDeviceLocalCredential
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint, userID: nil) {
    case let .available(credential):
      localCredential = credential
    case .unavailable:
      throw ClerkClientError(
        message: "Trusted-device sign-in is unavailable."
      )
    }
    let trustedDeviceId = localCredential.id

    let signIn: SignIn
    do {
      signIn = try await signInService.create(params: .init(
        strategy: .trustedDevice,
        trustedDeviceId: trustedDeviceId
      ))
    } catch {
      throw handleTrustedDeviceSignInError(error, localCredential: localCredential)
    }

    let challenge = try trustedDeviceChallenge(from: signIn)
    let signature = try keyManager.sign(
      clientData: challenge.clientData,
      localKeyId: localCredential.localKeyId,
      localizedReason: reason ?? "Use biometrics to sign in."
    )

    do {
      return try await signInService.attemptFirstFactor(
        signInId: signIn.id,
        params: .init(
          strategy: .trustedDevice,
          trustedDeviceId: trustedDeviceId,
          clientData: signature.clientData,
          signature: signature.signature,
          algorithm: signature.algorithm
        )
      )
    } catch {
      throw handleTrustedDeviceSignInError(error, localCredential: localCredential)
    }
  }
}

extension TrustedDevices {
  package func validateLocalCredentialIfPossible(
    id: String? = nil,
    identifierHint: String? = nil
  ) async -> TrustedDeviceValidationResult {
    if trustedDeviceFeatureUnavailableReason == .environmentUnavailable {
      return .inconclusive
    }

    let localCredentials: [TrustedDeviceLocalCredential]
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

    var firstUnavailableReason: TrustedDeviceAvailability.UnavailableReason?

    for localCredential in localCredentials {
      do {
        let validation = try await trustedDeviceService.validateSignInCredential(trustedDeviceId: localCredential.id)
        guard validation.valid else {
          try? deleteLocalCredential(localCredential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }
        return .valid
      } catch {
        if error.isMissingTrustedDeviceCredential {
          try? deleteLocalCredential(localCredential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }
        if let unavailableReason = error.trustedDeviceValidationUnavailableReason {
          return .invalid(unavailableReason)
        }
        return .inconclusive
      }
    }

    return .invalid(firstUnavailableReason ?? .serverCredentialMissing)
  }

  private var trustedDeviceFeatureUnavailableReason: TrustedDeviceAvailability.UnavailableReason? {
    guard let nativeSettings = Clerk.shared.environment?.authConfig.nativeSettings else {
      return .environmentUnavailable
    }
    guard nativeSettings.apiEnabled else {
      return .nativeAPIDisabled
    }
    guard nativeSettings.trustedDeviceSignInEnabled else {
      return .featureDisabled
    }
    return nil
  }

  private func ensureTrustedDeviceFeatureEnabled() throws {
    guard let reason = trustedDeviceFeatureUnavailableReason else {
      return
    }

    switch reason {
    case .environmentUnavailable:
      throw ClerkClientError(message: "Unable to use trusted-device sign-in before the Clerk environment is loaded.")
    case .nativeAPIDisabled:
      throw ClerkClientError(message: "Unable to use trusted-device sign-in because Native API is disabled.")
    case .featureDisabled:
      throw ClerkClientError(message: "Unable to use trusted-device sign-in because it is disabled.")
    default:
      throw ClerkClientError(message: "Trusted-device sign-in is unavailable.")
    }
  }

  private enum LocalCredentialResult<Value> {
    case available(Value)
    case unavailable(TrustedDeviceAvailability.UnavailableReason)
  }

  private func selectedLocalCredential(
    id: String?,
    identifierHint: String?,
    userID: String?
  ) async throws -> LocalCredentialResult<TrustedDeviceLocalCredential> {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint, userID: userID) {
    case let .available(supportedCredentials):
      guard Clerk.shared.session?.status == .active else {
        return .available(supportedCredentials[0])
      }

      guard let activeUserID = Clerk.shared.session?.user?.id else {
        return .available(supportedCredentials[0])
      }

      var trustedDevices: [TrustedDevice]?
      var firstUnavailableReason: TrustedDeviceAvailability.UnavailableReason?

      for credential in supportedCredentials {
        guard credential.userID == activeUserID else {
          return .available(credential)
        }

        let activeUserTrustedDevices: [TrustedDevice]
        if let trustedDevices {
          activeUserTrustedDevices = trustedDevices
        } else {
          let fetchedTrustedDevices = try await trustedDeviceService.list()
          trustedDevices = fetchedTrustedDevices
          activeUserTrustedDevices = fetchedTrustedDevices
        }

        guard let trustedDevice = activeUserTrustedDevices.first(where: { $0.id == credential.id }) else {
          try deleteLocalCredential(credential)
          firstUnavailableReason = firstUnavailableReason ?? .serverCredentialMissing
          continue
        }

        guard trustedDevice.status == .active else {
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
  ) throws -> LocalCredentialResult<[TrustedDeviceLocalCredential]> {
    if let unavailableReason = trustedDeviceFeatureUnavailableReason {
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
  ) throws -> [TrustedDeviceLocalCredential] {
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

  private func storedLocalCredentialsForCurrentApp() throws -> [TrustedDeviceLocalCredential] {
    guard let appIdentifier = appIdentifierProvider() else {
      return []
    }

    return try credentialStore.all(appIdentifier: appIdentifier)
  }

  private func localCredentialsWithExistingKeys(
    from credentials: [TrustedDeviceLocalCredential]
  ) throws -> [TrustedDeviceLocalCredential] {
    var credentialsWithKeys: [TrustedDeviceLocalCredential] = []

    for credential in credentials {
      if try localKeyExists(for: credential) {
        credentialsWithKeys.append(credential)
      } else {
        try deleteLocalCredential(credential)
      }
    }

    return credentialsWithKeys
  }

  private func localKeyExists(for credential: TrustedDeviceLocalCredential) throws -> Bool {
    do {
      return try keyManager.hasKey(localKeyId: credential.localKeyId)
    } catch let error as TrustedDeviceKeyManagerError where error == .keyNotFound {
      return false
    }
  }

  private func deleteLocalCredential(_ credential: TrustedDeviceLocalCredential) throws {
    try keyManager.deleteKey(localKeyId: credential.localKeyId)
    try credentialStore.delete(id: credential.id)
  }

  private func saveLocalCredential(
    trustedDevice: TrustedDevice,
    localKey: TrustedDeviceLocalKey,
    userID: String,
    identifierHint: String?
  ) async throws {
    do {
      try credentialStore.save(
        .init(
          trustedDevice: trustedDevice,
          localKey: localKey,
          userID: userID,
          identifierHint: identifierHint
        ),
        deleteReplacedLocalKey: { localKeyId in
          try keyManager.deleteKey(localKeyId: localKeyId)
        }
      )
    } catch {
      _ = try? await trustedDeviceService.revoke(trustedDeviceId: trustedDevice.id)
      throw error
    }
  }

  private func removeOtherLocalCredentialsForCurrentApp(keeping trustedDevice: TrustedDevice) {
    let credentialsToReplace: [TrustedDeviceLocalCredential]
    do {
      credentialsToReplace = try storedLocalCredentialsForCurrentApp().filter { $0.id != trustedDevice.id }
    } catch {
      ClerkLogger.warning(
        "Failed to load replaced trusted-device credentials for local cleanup. Error: \(error)"
      )
      return
    }

    for credential in credentialsToReplace {
      do {
        try deleteLocalCredential(credential)
      } catch {
        ClerkLogger.warning(
          "Failed to remove replaced trusted-device credential locally. Error: \(error)"
        )
      }
    }
  }

  private func trustedDeviceChallenge(from signIn: SignIn) throws -> TrustedDeviceChallenge {
    guard let trustedDeviceChallenge = signIn.firstFactorVerification?.trustedDeviceChallenge else {
      throw ClerkClientError(message: "Trusted-device sign-in did not return a challenge.")
    }
    return trustedDeviceChallenge
  }

  private func handleTrustedDeviceSignInError(
    _ error: Error,
    localCredential: TrustedDeviceLocalCredential
  ) -> Error {
    guard error.isMissingTrustedDeviceCredential else {
      return error
    }

    try? deleteLocalCredential(localCredential)
    return ClerkClientError(message: "This device is no longer trusted. Sign in another way to enroll it again.")
  }
}

extension Error {
  fileprivate var isMissingTrustedDeviceCredential: Bool {
    guard let error = self as? ClerkAPIError else {
      return false
    }

    return ["form_resource_not_found", "trusted_device_not_registered"].contains(error.code) &&
      error.meta?["param_name"]?.stringValue == "trusted_device_id"
  }

  fileprivate var trustedDeviceValidationUnavailableReason: TrustedDeviceAvailability.UnavailableReason? {
    guard let error = self as? ClerkAPIError else {
      return nil
    }

    switch error.code {
    case "native_api_disabled":
      return .nativeAPIDisabled
    case "feature_not_enabled":
      return .featureDisabled
    default:
      return nil
    }
  }
}

extension Session.SessionStatus {
  package var allowsTrustedDeviceEnrollment: Bool {
    switch self {
    case .active, .pending:
      true
    default:
      false
    }
  }
}
