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
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  /// Returns local trusted-device sign-in availability without reconciling with the server.
  package func localAvailability(
    id: String? = nil,
    identifierHint: String? = nil
  ) throws -> TrustedDeviceAvailability {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint) {
    case .available:
      .available
    case let .unavailable(reason):
      .unavailable(reason)
    }
  }

  /// Enrolls the current app installation as a biometric trusted device.
  ///
  /// This requires an active or pending Clerk session. The generated private key stays on the device.
  /// - Parameters:
  ///   - name: A human-readable device name stored with the trusted-device credential.
  ///   - identifierHint: A local-only user identifier hint for selecting this credential later.
  ///   - reason: The reason shown in the system biometric prompt.
  ///   - policy: The local authentication policy used to protect the generated private key.
  @discardableResult
  public func enroll(
    name: String? = nil,
    identifierHint: String? = nil,
    reason: String? = nil,
    policy: TrustedDevicePolicy = .biometryCurrentSet
  ) async throws -> TrustedDevice {
    guard Clerk.shared.session?.status.allowsTrustedDeviceEnrollment == true else {
      throw ClerkClientError(message: "Unable to enroll a trusted device without an active or pending Clerk session.")
    }
    try ensureTrustedDeviceFeatureEnabled()

    guard let appIdentifier = appIdentifierProvider() else {
      throw ClerkClientError(message: "Unable to enroll a trusted device without a bundle identifier.")
    }

    let localKey = try keyManager.createKey(policy: policy)
    do {
      let challenge = try await trustedDeviceService.prepareEnrollment(params: .init(
        appIdentifier: appIdentifier,
        name: name,
        publicKeyJWK: localKey.publicKeyJWK
      ))
      let signature = try keyManager.sign(
        clientData: challenge.clientData,
        localKeyId: localKey.localKeyId,
        localizedReason: reason ?? "Use biometrics to enroll this device."
      )
      let trustedDevice = try await trustedDeviceService.attemptEnrollment(params: .init(
        appIdentifier: appIdentifier,
        name: name,
        publicKeyJWK: localKey.publicKeyJWK,
        clientData: signature.clientData,
        signature: signature.signature
      ))
      try await saveLocalCredential(
        trustedDevice: trustedDevice,
        localKey: localKey,
        identifierHint: identifierHint
      )
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
    if let localCredential = try credentialStore.credential(id: id) {
      try deleteLocalCredential(localCredential)
    }
    return trustedDevice
  }

  /// Revokes the available local trusted-device credential for the current signed-in user.
  @discardableResult
  package func revokeCurrentDeviceCredential(identifierHint: String? = nil) async throws -> TrustedDevice? {
    guard Clerk.shared.session?.status.allowsTrustedDeviceEnrollment == true else {
      throw ClerkClientError(message: "Unable to revoke a trusted device without an active or pending Clerk session.")
    }

    switch try await selectedLocalCredential(id: nil, identifierHint: identifierHint) {
    case let .available(localCredential):
      return try await revoke(id: localCredential.id)
    case .unavailable:
      return nil
    }
  }

  /// Deletes locally stored trusted-device credentials matching an identifier hint.
  ///
  /// This is local cleanup only. Use ``revoke(id:)`` when the server-side trusted-device
  /// credential should be revoked for an active user.
  @discardableResult
  package func forgetLocalCredentials(identifierHint: String?) throws -> Int {
    let credentials = try credentialStore.all().filter { credential in
      if let identifierHint {
        credential.matches(identifierHint: identifierHint)
      } else {
        credential.identifierHint == nil
      }
    }

    for credential in credentials {
      try deleteLocalCredential(credential)
    }

    return credentials.count
  }

  /// Signs in with a locally enrolled biometric trusted-device credential.
  ///
  /// - Parameters:
  ///   - id: The trusted-device credential ID to use. When omitted, the newest local credential is selected.
  ///   - identifierHint: A local-only user identifier hint used to choose a matching credential.
  ///   - reason: The reason shown in the system biometric prompt.
  @discardableResult
  public func signIn(
    id: String? = nil,
    identifierHint: String? = nil,
    reason: String? = nil
  ) async throws -> SignIn {
    let localCredential: TrustedDeviceLocalCredential
    switch try await selectedLocalCredential(id: id, identifierHint: identifierHint) {
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

  private enum LocalCredentialSelection {
    case available(TrustedDeviceLocalCredential)
    case unavailable(TrustedDeviceAvailability.UnavailableReason)
  }

  private enum LocalCredentialCandidates {
    case available([TrustedDeviceLocalCredential])
    case unavailable(TrustedDeviceAvailability.UnavailableReason)
  }

  private func selectedLocalCredential(
    id: String?,
    identifierHint: String?
  ) async throws -> LocalCredentialSelection {
    switch try localCredentialCandidates(id: id, identifierHint: identifierHint) {
    case let .available(supportedCredentials):
      guard Clerk.shared.session?.status == .active else {
        return .available(supportedCredentials[0])
      }

      let trustedDevices = try await trustedDeviceService.list()
      var firstUnavailableReason: TrustedDeviceAvailability.UnavailableReason?

      for credential in supportedCredentials {
        guard let trustedDevice = trustedDevices.first(where: { $0.id == credential.id }) else {
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
    identifierHint: String?
  ) throws -> LocalCredentialCandidates {
    if let unavailableReason = trustedDeviceFeatureUnavailableReason {
      return .unavailable(unavailableReason)
    }

    let localCredentials = try candidateLocalCredentials(id: id, identifierHint: identifierHint)
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
    identifierHint: String?
  ) throws -> [TrustedDeviceLocalCredential] {
    var credentials = try credentialStore.all()
    if let id {
      credentials = credentials.filter { $0.id == id }
    }
    credentials = credentials.filter { $0.matches(identifierHint: identifierHint) }
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
    identifierHint: String?
  ) async throws {
    do {
      try credentialStore.save(.init(
        trustedDevice: trustedDevice,
        localKey: localKey,
        identifierHint: identifierHint
      ))
    } catch {
      _ = try? await trustedDeviceService.revoke(trustedDeviceId: trustedDevice.id)
      throw error
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

    return error.code == "form_resource_not_found" &&
      error.meta?["param_name"]?.stringValue == "trusted_device_id"
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
