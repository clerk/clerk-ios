//
//  ClerkRuntime.swift
//  ClerkKit
//

import Foundation

/// Everything Clerk builds for one installed configuration: the dependency container,
/// the managers that run beside it, their observers, and the tasks they start.
@MainActor
final class ClerkRuntime {
  weak let clerk: Clerk?
  var dependencies: any Dependencies
  var internalStateChanges = ClerkInternalStateChangeEmitter()

  private let tasks = TaskCoordinator()
  private var cacheManager: CacheManager?
  private var sessionPollingManager: SessionPollingManager?
  private var lifecycleManager: LifecycleManager?
  private var watchConnectivityCoordinator: WatchConnectivityCoordinator?
  private var sharedIdentityNotifier: SharedIdentityNotifier?

  init(clerk: Clerk, dependencies: any Dependencies) {
    self.clerk = clerk
    self.dependencies = dependencies
  }

  func start() {
    stop()
    guard let clerk else { return }

    clerk.identityController.prepareForConfiguration()
    clerk.reconcileBiometricCredentialsForCurrentInstallation()

    let sessionPollingManager = SessionPollingManager(
      sessionProvider: clerk,
      authEventsProvider: { [weak clerk] in
        clerk?.auth.events ?? AsyncStream { $0.finish() }
      }
    )
    let lifecycleManager = LifecycleManager(handler: self)
    self.sessionPollingManager = sessionPollingManager
    self.lifecycleManager = lifecycleManager
    sessionPollingManager.startPolling()
    lifecycleManager.startObserving()

    clerk.identityController.hydrate()

    let cacheManager = CacheManager(coordinator: clerk, keychain: dependencies.appLocalKeychain)
    self.cacheManager = cacheManager
    internalStateChanges.addObserver(cacheManager)
    cacheManager.loadCachedData()

    if dependencies.configurationManager.options.watchConnectivityEnabled {
      let coordinator = WatchConnectivityCoordinator()
      watchConnectivityCoordinator = coordinator
      internalStateChanges.addObserver(coordinator)
    }
    installSharedIdentityNotifier(clerk: clerk)
  }

  func stop() {
    stopManagers()
    tasks.cancelAll()
  }

  func shutdown() async {
    stopManagers()
    await tasks.cancelAllAndWait()
  }

  @discardableResult
  func scheduleTask(
    priority: TaskPriority = .userInitiated,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    tasks.task(priority: priority, operation: operation)
  }

  private func installSharedIdentityNotifier(clerk: Clerk) {
    let keychainConfig = dependencies.configurationManager.options.keychainConfig
    guard dependencies.identityIsInAccessGroup, let accessGroup = keychainConfig.normalizedAccessGroup else { return }
    let notifier = SharedIdentityNotifier(name: "\(accessGroup).clerk.\(keychainConfig.service)", clerk: clerk)
    sharedIdentityNotifier = notifier
    internalStateChanges.addObserver(notifier)
  }

  private func stopManagers() {
    watchConnectivityCoordinator?.stopAcceptingIdentityUpdates()
    watchConnectivityCoordinator = nil
    sharedIdentityNotifier?.stop()
    sharedIdentityNotifier = nil
    cacheManager?.shutdown()
    cacheManager = nil
    sessionPollingManager?.stopPolling()
    sessionPollingManager = nil
    lifecycleManager?.stopObserving()
    lifecycleManager = nil
    internalStateChanges.removeAllObservers()
  }
}

extension ClerkRuntime: LifecycleEventHandling {
  func onWillEnterForeground() async {
    guard let clerk else { return }
    sessionPollingManager?.startPolling()

    clerk.identityController.adoptStoredDeviceToken()
    clerk.emitInternalStateChange(.applicationDidEnterForeground)

    #if os(macOS)
    if WebAuthentication.consumePendingForegroundRefreshSuppression() {
      return
    }
    #endif

    tasks.task { [weak self, weak clerk] in
      guard let self, let clerk else { return }
      do {
        try await clerk.refreshClient()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client on foreground")
      }

      // Force an immediate token evaluation after foreground client refresh
      // rather than waiting for the next polling interval.
      await sessionPollingManager?.refreshNowIfNeeded()
    }

    tasks.task { [weak clerk] in
      guard let clerk else { return }
      do {
        _ = try await clerk.refreshEnvironment()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh environment on foreground")
      }
    }
  }

  func onDidEnterBackground() async {
    sessionPollingManager?.stopPolling()

    let telemetry = dependencies.telemetryCollector
    tasks.task(priority: .utility) {
      await telemetry.flush()
    }
  }
}
