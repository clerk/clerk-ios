//
//  ClerkRuntimeServices.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol defining runtime services that manage Clerk's lifecycle, polling, and platform-specific features.
///
/// This protocol allows for dependency injection of runtime services, making it easier to test
/// and customize behavior for different platforms or testing scenarios.
protocol ClerkRuntimeServicesProtocol: Sendable {
  /// Starts all runtime services (polling, lifecycle observation, etc.).
  @MainActor func start()

  /// Stops all runtime services and cleans up resources.
  @MainActor func stop()

  /// Resumes runtime services (e.g., when app enters foreground).
  @MainActor func resume()

  /// Pauses runtime services (e.g., when app enters background).
  @MainActor func pause()
}

/// Default implementation of runtime services for Clerk.
///
/// This class manages session polling, app lifecycle, and watch connectivity
/// for the standard Clerk SDK behavior.
@MainActor
final class ClerkRuntimeServices: ClerkRuntimeServicesProtocol {
  /// Manages periodic polling of session tokens to keep them refreshed.
  private let sessionPollingManager: SessionPollingManager

  /// Manages app lifecycle notifications and coordinates foreground/background transitions.
  private let lifecycleManager: LifecycleManager

  /// Unified Watch Connectivity sync interface for both iOS and watchOS platforms.
  private let watchConnectivitySync: (any WatchConnectivitySyncing)?

  /// Creates a new runtime services instance.
  ///
  /// - Parameters:
  ///   - sessionProvider: The provider that supplies the current active session for token retrieval.
  ///   - lifecycleHandler: The handler that responds to lifecycle events.
  ///   - watchConnectivitySync: Optional watch connectivity sync interface. If nil, watch connectivity is disabled.
  init(
    sessionProvider: any SessionProviding,
    lifecycleHandler: any LifecycleEventHandling,
    watchConnectivitySync: (any WatchConnectivitySyncing)? = nil
  ) {
    self.sessionPollingManager = SessionPollingManager(sessionProvider: sessionProvider)
    self.lifecycleManager = LifecycleManager(handler: lifecycleHandler)
    self.watchConnectivitySync = watchConnectivitySync
  }

  /// Starts all runtime services.
  func start() {
    sessionPollingManager.startPolling()
    lifecycleManager.startObserving()
  }

  /// Stops all runtime services and cleans up resources.
  func stop() {
    sessionPollingManager.stopPolling()
    lifecycleManager.stopObserving()
  }

  /// Resumes runtime services (e.g., when app enters foreground).
  func resume() {
    sessionPollingManager.startPolling()
  }

  /// Pauses runtime services (e.g., when app enters background).
  func pause() {
    sessionPollingManager.stopPolling()
  }
}

/// No-op implementation of runtime services for testing or when runtime services are not needed.
@MainActor
final class NoOpRuntimeServices: ClerkRuntimeServicesProtocol {
  func start() {}
  func stop() {}
  func resume() {}
  func pause() {}
}

