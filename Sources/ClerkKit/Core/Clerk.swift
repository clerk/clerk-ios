//
//  Clerk.swift
//

// swiftlint:disable file_length

import Foundation

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
public final class Clerk {
  /// The shared Clerk instance.
  ///
  /// Accessing this property before calling `Clerk.configure(publishableKey:options:)` will trigger an assertion failure in debug builds.
  /// In release builds, a new unconfigured `Clerk` instance is returned.
  public static var shared: Clerk {
    guard let instance = _shared else {
      assertionFailure("Clerk has not been configured. Call Clerk.configure(publishableKey:options:) before accessing Clerk.shared")
      return Clerk()
    }
    return instance
  }

  private static var _shared: Clerk?

  static var installedLoggingConfiguration: ClerkLogger.Configuration? {
    _shared.map { ClerkLogger.Configuration(options: $0.options) }
  }

  private static var isRuntimeReconfigurationInProgress = false
  private static var runtimeReconfigurationWaiters: [CheckedContinuation<Void, Never>] = []

  private struct ReconfigurationRollbackState {
    let configurationEpoch: ClerkConfigurationEpoch
    let identity: ClerkIdentityController.RollbackState
  }

  /// A getter to see if the Clerk object is ready for use or not.
  /// Returns true when both environment and client are loaded.
  public var isLoaded: Bool {
    environment != nil && client != nil
  }

  /// A getter to see if a Clerk instance is running in production or development mode.
  public var instanceType: InstanceEnvironmentType {
    dependencies.configurationManager.instanceType
  }

  /// Whether ClerkKitUI should show the development mode warning.
  public var shouldShowDevelopmentModeWarning: Bool {
    guard let displayConfig = environment?.displayConfig else { return false }
    return displayConfig.showDevmodeWarning && displayConfig.instanceEnvironmentType != .production
  }

  /// The Client object for the current device.
  public internal(set) var client: Client? {
    didSet {
      if SessionUtils.sessionChanged(previousClient: oldValue, currentClient: client) {
        auth.send(.sessionChanged(oldValue: oldValue?.currentSession, newValue: client?.currentSession))
      }

      if let client {
        dependencies.sessionStatusLogger.logPendingSessionStatusIfNeeded(previousClient: oldValue, currentClient: client)
      }

      emitInternalStateChange(.clientDidChange(previous: oldValue, current: client))
    }
  }

  /// The telemetry collector for development diagnostics.
  ///
  /// Uses dependency injection with a no-op default that is replaced with a real collector
  /// during configuration if telemetry is enabled.
  /// Used to record non-blocking telemetry events when running in development
  package var telemetry: any TelemetryCollectorProtocol {
    dependencies.telemetryCollector
  }

  /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
  public private(set) var proxyUrl: URL? {
    get {
      dependencies.configurationManager.proxyUrl
    }
    set {
      dependencies.configurationManager.updateProxyUrl(newValue)
    }
  }

  /// The current session for the device.
  public var session: Session? {
    client?.currentSession
  }

  /// The current user for the device.
  public var user: User? {
    session?.user
  }

  /// The current user's membership in the active organization.
  public var organizationMembership: OrganizationMembership? {
    guard let activeOrganizationId = session?.lastActiveOrganizationId else {
      return nil
    }

    return user?.organizationMemberships?.first { $0.organization.id == activeOrganizationId }
  }

  /// The active organization for the current session.
  public var organization: Organization? {
    organizationMembership?.organization
  }

  /// A dictionary of a user's active sessions on all devices.
  public internal(set) var sessionsByUserId: [String: [Session]] = [:]

  /// Server timestamp from the response that last updated the local client.
  /// Used as a cross-device ordering key, since it comes from a
  /// single clock (the server) and advances on every API response.
  var lastClientServerFetchDate: Date? {
    identityController.lastServerDate
  }

  /// The client that has crossed an authoritative persistence or response boundary.
  var authoritativeClient: Client? {
    identityController.authoritativeClient
  }

  /// Changes when local device-token ownership changes.
  /// Client responses prepared before this value changes must not update state.
  var clientResponseGeneration: ClientResponseGeneration {
    identityController.clientResponseGeneration
  }

  /// Changes every time this instance is reconfigured.
  /// SDK-owned requests capture this value so stale responses cannot mutate new state.
  @ObservationIgnored
  private(set) var configurationEpoch: ClerkConfigurationEpoch = .initial

  let runtimeState = ClerkRuntimeState()

  /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
  public var publishableKey: String {
    dependencies.configurationManager.publishableKey
  }

  /// The Clerk environment for the instance.
  public internal(set) var environment: Environment? {
    didSet {
      if environment != nil {
        emitInternalStateChange(.environmentDidChange)
      }
    }
  }

  package struct EnvironmentRefreshCheckpoint: Equatable {
    fileprivate let revision: Int
  }

  private var environmentRefreshRevision = 0

  package var environmentRefreshCheckpoint: EnvironmentRefreshCheckpoint {
    .init(revision: environmentRefreshRevision)
  }

  /// The configuration options for this Clerk instance.
  public var options: Clerk.Options {
    dependencies.configurationManager.options
  }

  var frontendApiUrl: String {
    dependencies.configurationManager.frontendApiUrl
  }

  @ObservationIgnored
  lazy var identityController = ClerkIdentityController(clerk: self)

  @ObservationIgnored
  private(set) lazy var runtime = ClerkRuntime(clerk: self, dependencies: Self.makeUnconfiguredDependencies())

  var dependencies: any Dependencies {
    get { runtime.dependencies }
    set { runtime.dependencies = newValue }
  }

  /// The event emitter for auth events.
  /// Owned by Clerk to ensure stable identity across accesses to `auth`.
  private let authEventEmitter = EventEmitter<AuthEvent>()
  private let urlHandlingCoordinator = URLHandlingCoordinator()
  package private(set) var callbackContinuation: TransferFlowResult?

  var authFlowCoordinator = AuthFlowCoordinator()

  /// The main entry point for all authentication operations.
  ///
  /// Use this property to perform sign in, sign up, and session management operations.
  /// This is a lightweight facade - Clerk owns the underlying EventEmitter.
  public var auth: Auth {
    Auth(
      magicLinkStore: dependencies.magicLinkStore,
      magicLinkService: dependencies.magicLinkService,
      hostedAuthService: dependencies.hostedAuthService,
      signInService: dependencies.signInService,
      signUpService: dependencies.signUpService,
      sessionService: dependencies.sessionService,
      biometricCredentials: biometricCredentials,
      eventEmitter: authEventEmitter,
      urlHandlingCoordinator: urlHandlingCoordinator
    )
  }

  package func setCallbackContinuation(_ result: TransferFlowResult?) {
    callbackContinuation = result
  }

  /// The main entry point for organization operations.
  ///
  /// Use this property to create organizations.
  public var organizations: Organizations {
    Organizations(organizationService: dependencies.organizationService)
  }

  /// Reads Plans, Subscriptions, statements, payment attempts, and credits.
  public var billing: Billing {
    Billing(billingService: dependencies.billingService)
  }

  /// The main entry point for biometric credential operations.
  public var biometricCredentials: BiometricCredentials {
    BiometricCredentials(
      biometricCredentialService: dependencies.biometricCredentialService,
      signInService: dependencies.signInService,
      keyManager: dependencies.biometricCredentialKeyManager,
      credentialStore: dependencies.biometricCredentialStore
    )
  }

  var proxyConfiguration: ProxyConfiguration? {
    dependencies.configurationManager.proxyConfiguration
  }

  package init() {}

  private static func makeUnconfiguredDependencies() -> any Dependencies {
    do {
      return try DependencyContainer(
        publishableKey: "",
        options: .init(),
        runtimeScope: .init(epoch: .initial)
      )
    } catch {
      fatalError("Failed to create the unconfigured dependency container: \(error.localizedDescription)")
    }
  }
}

extension Clerk {
  @MainActor
  func performConfiguration(publishableKey: String, options: Clerk.Options) throws {
    let runtime = try makeRuntime(publishableKey: publishableKey, options: options, runtimeScope: runtimeScope)
    self.runtime.stop()
    install(runtime)
  }

  @MainActor
  func performConfiguration(dependencies: any Dependencies) {
    runtime.stop()
    install(ClerkRuntime(clerk: self, dependencies: dependencies))
  }

  private func makeRuntime(
    publishableKey: String,
    options: Clerk.Options,
    runtimeScope: ClerkRuntimeScope
  ) throws -> ClerkRuntime {
    let dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: runtimeScope
    )
    return ClerkRuntime(clerk: self, dependencies: dependencies)
  }

  private func install(_ runtime: ClerkRuntime) {
    self.runtime = runtime
    runtime.start()
  }

  /// Configures the shared Clerk instance.
  ///
  /// Call this method once at app launch before accessing `Clerk.shared`.
  ///
  /// - Parameters:
  ///     - publishableKey: The publishable key from your Clerk Dashboard.
  ///     - options: Configuration options for the Clerk instance.
  /// - Returns: The configured Clerk instance.
  @MainActor
  @discardableResult
  public static func configure(
    publishableKey: String,
    options: Clerk.Options = .init()
  ) -> Clerk {
    if let existing = _shared {
      if EnvironmentDetection.isRunningInTests {
        // Clean up old managers before resetting to prevent background tasks from interfering
        existing.cleanupManagers()
        _shared = nil
      } else {
        ClerkLogger.warning("Clerk has already been configured. Configure can only be called once.")
        return existing
      }
    }

    let clerk = Clerk()

    do {
      try clerk.performConfiguration(publishableKey: publishableKey, options: options)
    } catch {
      assertionFailure("Failed to configure Clerk: \(error.localizedDescription)")
      return Clerk()
    }

    _shared = clerk
    return clerk
  }

  @MainActor
  @discardableResult
  static func configureForTesting(
    publishableKey: String,
    options: Clerk.Options = .init(),
    keychainStorage: any KeychainStorage
  ) throws -> Clerk {
    guard EnvironmentDetection.isRunningInTests else {
      throw ClerkClientError(message: "Isolated Clerk configuration is only available while running tests.", localizationBundle: .module)
    }

    if let existing = _shared {
      existing.cleanupManagers()
      _shared = nil
    }

    let clerk = Clerk()
    let dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope,
      probesAccessGroupOverride: false,
      keychainStorageOverride: keychainStorage
    )
    clerk.performConfiguration(dependencies: dependencies)
    _shared = clerk
    return clerk
  }

  /// Reconfigures the shared Clerk instance with a new publishable key and options.
  ///
  /// This method validates the new configuration, clears local Clerk state, and then
  /// installs the new configuration on the existing shared instance. Any user currently
  /// signed in should be expected to sign in again after reconfiguration. An identity stored
  /// in a Keychain access group is left for the other apps in the group, and a destination
  /// configuration that uses the group adopts the identity those apps already share.
  ///
  /// If Clerk has not been configured yet, this method creates and installs the shared
  /// instance without going through the fallback ``Clerk/shared`` getter.
  ///
  /// - Parameters:
  ///   - publishableKey: The new publishable key from your Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  /// - Returns: The configured shared Clerk instance.
  /// - Throws: An error if the new configuration is invalid.
  ///
  /// Example:
  /// ```swift
  /// try await Clerk.reconfigure(
  ///   publishableKey: selectedRegion.publishableKey,
  ///   options: .init(proxyUrl: selectedRegion.proxyUrl)
  /// )
  /// ```
  @MainActor
  @discardableResult
  public static func reconfigure(
    publishableKey: String,
    options: Clerk.Options = .init()
  ) async throws -> Clerk {
    try beginRuntimeReconfiguration()
    defer { endRuntimeReconfiguration() }

    if let existing = _shared {
      _ = try existing.dependencies.keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

      let nextEpoch = existing.nextConfigurationEpoch
      let next = try existing.makeRuntime(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: .init(epoch: nextEpoch, runtimeState: existing.runtimeState, clerkProvider: { existing })
      )
      let outgoing = existing.runtime
      let rollbackState = existing.captureReconfigurationRollbackState()

      existing.setConfigurationEpoch(to: nextEpoch)
      await existing.cleanupManagersAndWait()

      do {
        try clearLocalClerkStorageStrictly(in: outgoing.dependencies)
        try clearLocalClerkStorageStrictly(in: next.dependencies)
      } catch {
        existing.restoreAfterFailedReconfiguration(rollbackState)
        throw error
      }

      await existing.resetRuntimeStateForReconfiguration()
      existing.install(next)
      return existing
    }

    let clerk = Clerk()
    let runtime = try clerk.makeRuntime(publishableKey: publishableKey, options: options, runtimeScope: clerk.runtimeScope)
    try clearLocalClerkStorageStrictly(in: runtime.dependencies)
    clerk.install(runtime)
    _shared = clerk
    return clerk
  }

  @MainActor
  static func resetSharedInstanceForTesting() async {
    guard EnvironmentDetection.isRunningInTests else {
      return
    }

    guard let shared = _shared else { return }

    await shared.cleanupManagersAndWait()
    await SessionTokenFetcher.shared.reset()
    shared.identityController.invalidateAllSessionTokens()
    _shared = nil
  }

  /// Refreshes the current client from the API.
  @discardableResult
  public func refreshClient() async throws -> Client? {
    try await refreshClient(skipClientId: false)
  }

  /// Refreshes the current client from the API.
  ///
  /// - Parameter skipClientId: When `true`, omits the currently cached client id
  ///   from the request while still sending the stored device token. This is used
  ///   after replacing the device token so a stale client id from the previous
  ///   native client cannot conflict with the newly stored token.
  @discardableResult
  func refreshClient(skipClientId: Bool) async throws -> Client? {
    try Task.checkCancellation()
    let runtime = runtimeScope
    let clientResponseGeneration = clientResponseGeneration
    let response = try await dependencies.clientService.getResponse(skipClientId: skipClientId)
    try Task.checkCancellation()
    try runtime.validateStableRuntime()
    switch response.update {
    case .client(let responseClient):
      identityController.applyResponseClient(
        responseClient,
        responseSequence: response.requestSequence,
        serverDate: response.serverDate,
        clientResponseGeneration: clientResponseGeneration
      )
    case .preserve:
      break
    }
    return client
  }

  /// Refreshes the current environment from the API.
  @discardableResult
  public func refreshEnvironment() async throws -> Environment {
    try await runtime.refreshEnvironment()
  }

  func applyRefreshedEnvironment(_ environment: Environment) {
    self.environment = environment
    environmentRefreshRevision += 1
  }

  @discardableResult
  package func ensureEnvironmentRefreshed(after checkpoint: EnvironmentRefreshCheckpoint) async throws -> Environment {
    if environmentRefreshRevision > checkpoint.revision, let environment {
      return environment
    }

    return try await refreshEnvironment()
  }

  /// Handles an incoming URL, routing it to the appropriate handler.
  ///
  /// If the URL matches a known Clerk callback (e.g. a magic link), it will
  /// be processed automatically and this method returns `true`. Unrecognized
  /// URLs are ignored and this method returns `false`.
  ///
  /// ```swift
  /// .onOpenURL { url in
  ///   Task { try? await clerk.handle(url) }
  /// }
  /// ```
  @discardableResult
  public func handle(_ url: URL) async throws -> Bool {
    guard let route = try ClerkURLRoute(url: url, redirectUrl: options.redirectConfig.redirectUrl) else {
      return false
    }

    try await auth.handle(route)
    return true
  }

  @MainActor
  private func resetRuntimeStateForReconfiguration() async {
    await SessionTokenFetcher.shared.reset()
    identityController.invalidateAllSessionTokens()

    resetAuthFlowForReconfiguration()
    identityController.resetRuntimeIdentity()
    environment = nil
    sessionsByUserId = [:]
    WebAuthentication.cancelCurrentSession()

    #if canImport(AuthenticationServices) && !os(watchOS)
    PasskeyHelper.cancelCurrentAuthorization()
    #endif
  }
}

extension Clerk: CacheCoordinator {
  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    // Only set if environment hasn't been loaded yet
    // This prevents cached data from overwriting fresh data loaded from the API
    guard self.environment == nil else { return }
    self.environment = environment
  }
}

extension Clerk: SessionProviding {}

extension Clerk {
  /// Applies a client value after the identity controller has established its mutation boundary.
  func setClientFromIdentityController(
    _ client: Client?,
    authFlowUpdate: AuthFlowIdentityUpdate = .ordinary
  ) {
    authFlowCoordinator.applyIdentity(
      previousClient: self.client,
      client: client,
      update: authFlowUpdate
    )
    self.client = client
  }

  func emitInternalStateChange(_ change: ClerkInternalStateChange) {
    do {
      try runtime.internalStateChanges.emit(change, from: self)
    } catch {
      ClerkLogger.logError(error, message: "Failed to notify Clerk state observer")
    }
  }

  @MainActor
  static func beginRuntimeReconfiguration() throws {
    guard !isRuntimeReconfigurationInProgress else {
      throw ClerkClientError(message: "Clerk is already reconfiguring. Wait for the current reconfiguration to finish before starting another one.", localizationBundle: .module)
    }
    isRuntimeReconfigurationInProgress = true
    _shared?.runtimeState.beginReconfiguration()
  }

  @MainActor
  static func endRuntimeReconfiguration() {
    isRuntimeReconfigurationInProgress = false
    _shared?.runtimeState.endReconfiguration()
    let waiters = runtimeReconfigurationWaiters
    runtimeReconfigurationWaiters.removeAll()
    waiters.forEach { $0.resume() }
  }

  @MainActor
  static var runtimeReconfigurationIsInProgress: Bool {
    isRuntimeReconfigurationInProgress
  }

  @MainActor
  static func waitForRuntimeReconfigurationIfNeeded() async {
    guard isRuntimeReconfigurationInProgress else { return }
    await withCheckedContinuation {
      runtimeReconfigurationWaiters.append($0)
    }
  }

  @MainActor
  static func requireStableRuntime() throws -> ClerkRuntimeScope {
    guard !isRuntimeReconfigurationInProgress else {
      throw CancellationError()
    }

    guard let shared = _shared else {
      throw ClerkClientError(message: "Clerk must be configured before getting a session token.", localizationBundle: .module)
    }

    return shared.runtimeScope
  }

  var runtimeScope: ClerkRuntimeScope {
    ClerkRuntimeScope.current(clerkProvider: { self })
  }

  var nextConfigurationEpoch: ClerkConfigurationEpoch {
    configurationEpoch.next()
  }

  func setConfigurationEpoch(to epoch: ClerkConfigurationEpoch) {
    configurationEpoch = epoch
    runtimeState.advance(to: epoch)
  }

  private func captureReconfigurationRollbackState() -> ReconfigurationRollbackState {
    ReconfigurationRollbackState(
      configurationEpoch: configurationEpoch,
      identity: identityController.captureRollbackState()
    )
  }

  private func restoreAfterFailedReconfiguration(
    _ state: ReconfigurationRollbackState
  ) {
    setConfigurationEpoch(to: state.configurationEpoch)
    identityController.restoreRollbackState(state.identity)
    runtime.start()
  }

  func isCurrentConfigurationEpoch(_ epoch: ClerkConfigurationEpoch) -> Bool {
    configurationEpoch == epoch
  }

  /// Cleans up managers that were started during configuration.
  /// Used during testing to ensure old managers are properly cleaned up before reconfiguration.
  package func cleanupManagers() {
    urlHandlingCoordinator.cancelAll()
    runtime.stop()
    resetManagerStateForCleanup(finishAuthEventStreams: true)
  }

  private func cleanupManagersAndWait() async {
    urlHandlingCoordinator.cancelAll()
    await runtime.shutdown()
    resetManagerStateForCleanup(finishAuthEventStreams: false)
  }

  private func resetManagerStateForCleanup(finishAuthEventStreams: Bool) {
    if finishAuthEventStreams {
      authEventEmitter.finish()
    }
    environmentRefreshRevision = 0
    callbackContinuation = nil
    identityController.resetOrderingState()
  }
}
