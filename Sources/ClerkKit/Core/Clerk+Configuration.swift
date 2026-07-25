//
//  Clerk+Configuration.swift
//

import Foundation

extension Clerk {
  private enum AppContainerIdentityClearBootstrapResult {
    case notNeeded
    case recovered
    case blocked(
      reason: PersistenceBlockReason,
      recoveryFailure: PersistenceFailureKind,
      requiresAtomicRouting: Bool
    )
  }

  typealias ConfigurationDependencyFactory = @MainActor (
    String,
    Clerk.Options,
    PersistenceFailureKind?
  ) throws -> DependencyContainer

  /// Internal helper method that performs the actual configuration work.
  @MainActor
  func performConfiguration(
    publishableKey: String,
    options: Clerk.Options,
    dependencyFactory: ConfigurationDependencyFactory? = nil
  ) throws {
    func makeDependencies(
      forceVolatileIdentityPersistence: PersistenceFailureKind? = nil
    ) throws -> DependencyContainer {
      if let dependencyFactory {
        return try dependencyFactory(
          publishableKey,
          options,
          forceVolatileIdentityPersistence
        )
      }
      return try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: runtimeScope,
        deferSharedSessionAdoption: true,
        persistenceFailureBehavior: .useVolatileStorage,
        forceVolatileIdentityPersistence: forceVolatileIdentityPersistence
      )
    }

    var dependencies = try makeDependencies()
    switch recoverAppContainerIdentityClearBeforeBootstrap(
      protecting: dependencies
    ) {
    case .notNeeded:
      break
    case .recovered:
      // Recovery can establish the durable adoption barrier after the first
      // container selected its storage mode. Rebuild only on this exceptional
      // path so the installed runtime uses the recovered topology.
      dependencies = try makeDependencies()
    case .blocked(
      let blockReason,
      let recoveryFailure,
      let requiresAtomicRouting
    ):
      // A partially completed recovery can also establish the adoption
      // barrier before a later cleanup step fails. Rebuild before installing
      // the blocked runtime so a foreground retry cannot resume with stale
      // persistence routing.
      let rebuiltDependencies = try makeDependencies()
      if requiresAtomicRouting,
         !rebuiltDependencies.usesVolatileIdentityPersistence,
         rebuiltDependencies.atomicIdentityStore == nil
      {
        dependencies = try makeDependencies(
          forceVolatileIdentityPersistence: recoveryFailure
        )
      } else {
        dependencies = rebuiltDependencies
      }
      installConfiguration(
        dependencies: dependencies,
        bootstrapBlockReason: blockReason
      )
      return
    }

    do {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
        in: dependencies.sharedSessionOwnerSlotClearRecovery
      )
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      guard failure.permitsVolatileIdentityFallback else {
        installConfiguration(
          dependencies: dependencies,
          bootstrapBlockReason: failure.blockReason
        )
        return
      }
      dependencies = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: runtimeScope,
        deferSharedSessionAdoption: true,
        forceVolatileIdentityPersistence: failure
      )
      ClerkLogger.logError(
        error,
        message: "Durable Clerk clear recovery is unavailable. Continuing with isolated in-memory identity for this process."
      )
    }

    if let bootstrapFailure =
      dependencies.identityPersistenceBootstrapFailure
    {
      installConfiguration(
        dependencies: dependencies,
        bootstrapBlockReason: bootstrapFailure.blockReason
      )
      return
    }

    do {
      try dependencies.probeLocalIdentityPersistence()
      try dependencies.discardPendingPublicationWhenSharedSyncDisabled()
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      guard failure.permitsVolatileIdentityFallback else {
        installConfiguration(
          dependencies: dependencies,
          bootstrapBlockReason: failure.blockReason
        )
        return
      }
      dependencies = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: runtimeScope,
        deferSharedSessionAdoption: true,
        forceVolatileIdentityPersistence: failure
      )
    }

    installConfiguration(dependencies: dependencies)
  }

  /// Internal helper method that installs a prebuilt dependency container and starts managers.
  @MainActor
  func performConfiguration(dependencies: any Dependencies) throws {
    switch recoverAppContainerIdentityClearBeforeBootstrap(
      protecting: dependencies
    ) {
    case .notNeeded, .recovered:
      break
    case .blocked(let blockReason, _, _):
      installConfiguration(
        dependencies: dependencies,
        bootstrapBlockReason: blockReason
      )
      return
    }
    try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
      in: dependencies.sharedSessionOwnerSlotClearRecovery
    )
    try dependencies.probeLocalIdentityPersistence()
    installConfiguration(dependencies: dependencies)
  }

  /// Completes an explicit clear before any persisted identity can be hydrated.
  /// A valid unresolved intent always blocks identity; an unreadable or malformed
  /// intent fails closed without guessing at a deletion target.
  private func recoverAppContainerIdentityClearBeforeBootstrap(
    protecting currentDependencies: any Dependencies
  )
    -> AppContainerIdentityClearBootstrapResult
  {
    let intent: AppContainerIdentityClearIntent
    do {
      guard let pendingIntent = try appContainerIdentityClearIntentStore.load()
      else {
        return .notNeeded
      }
      intent = pendingIntent
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      ClerkLogger.logError(
        error,
        message: "Clerk could not read its pending app-container identity clear."
      )
      return .blocked(
        reason: failure.blockReason,
        recoveryFailure: failure,
        requiresAtomicRouting: false
      )
    }

    do {
      try recoverAppContainerIdentityClear(
        intent,
        protecting: currentDependencies
      )
      try appContainerIdentityClearIntentStore.remove(
        matching: intent.transactionID
      )
      return .recovered
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      ClerkLogger.logError(
        error,
        message: "Clerk could not complete its pending durable identity clear."
      )
      return .blocked(
        reason: .pendingClear,
        recoveryFailure: failure,
        requiresAtomicRouting:
        appContainerIdentityClearCanChangeCurrentPersistenceRouting(
          intent,
          protecting: currentDependencies
        )
      )
    }
  }

  func appContainerIdentityClearCanChangeCurrentPersistenceRouting(
    _ intent: AppContainerIdentityClearIntent,
    protecting currentDependencies: any Dependencies
  ) -> Bool {
    guard intent.ownerSlot != nil else { return false }
    let currentConfiguration =
      currentDependencies.configurationManager
    let currentFingerprint = SharedSessionNamespace(
      frontendApiUrl: currentConfiguration.frontendApiUrl,
      publishableKey: currentConfiguration.publishableKey
    ).fingerprint
    guard currentFingerprint == intent.instanceFingerprint,
          let currentIntent =
          try? Self.makeAppContainerIdentityClearIntent(
            dependencies: currentDependencies,
            options: currentConfiguration.options,
            frontendApiUrl: currentConfiguration.frontendApiUrl,
            publishableKey: currentConfiguration.publishableKey
          )
    else {
      return false
    }
    return currentIntent.ownerIdentifier == intent.ownerIdentifier
      && currentIntent.stableIdentity == intent.stableIdentity
  }
}
