//
//  WatchConnectivityManager.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if os(iOS)
import WatchConnectivity

/// Manages Watch Connectivity session for syncing authentication state to companion watchOS app.
///
/// This manager handles sending the deviceToken, Client, and Environment to the watch app whenever
/// they change or when the app enters the foreground. It uses WCSession's updateApplicationContext
/// for reliable delivery even when the watch app is not running.
final class WatchConnectivityManager: NSObject, WatchConnectivitySyncing {
  /// The WCSession instance used for communication.
  private let session: WCSession

  private let payloadHandler: @MainActor (WatchSyncPayload) -> Void
  private let activationHandler: @MainActor () -> Void
  private let operationHandler: @MainActor (Data) async throws -> Data

  /// Whether the session is currently activated. Must be accessed from MainActor.
  @MainActor
  private var isSessionActivated = false

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  @MainActor
  private var pendingPayload: WatchSyncPayload?

  /// Creates a new Watch Connectivity manager.
  init(
    payloadHandler: @escaping @MainActor (WatchSyncPayload) -> Void,
    activationHandler: @escaping @MainActor () -> Void,
    operationHandler: @escaping @MainActor (Data) async throws -> Data
  ) {
    session = WCSession.default
    self.payloadHandler = payloadHandler
    self.activationHandler = activationHandler
    self.operationHandler = operationHandler
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  /// Sends Clerk's reduced watch-sync payload to the watch app.
  @MainActor
  func sync(_ payload: WatchSyncPayload) {
    guard !isProcessingSync else {
      ClerkLogger.info(
        "clerk-watch-sync diag context-drop busy session=\(payload.clientUpdate.client?.lastActiveSessionId ?? "nil")",
        force: true
      )
      return
    }
    pendingPayload = payload
    syncPendingPayloadIfPossible()
  }

  @MainActor
  private func applyPayload(_ payload: WatchSyncPayload) {
    isProcessingSync = true
    defer { isProcessingSync = false }
    payloadHandler(payload)
  }

  @MainActor
  private func syncPendingPayloadIfPossible() {
    guard isSessionActivated, session.isPaired, session.isWatchAppInstalled else { return }
    guard let payload = pendingPayload else { return }

    let applicationContext = payload.applicationContext

    guard !applicationContext.isEmpty else {
      pendingPayload = nil
      return
    }

    do {
      try session.updateApplicationContext(applicationContext)
      pendingPayload = nil
      ClerkLogger.info(
        "clerk-watch-sync diag context-sent session=\(payload.clientUpdate.client?.lastActiveSessionId ?? "nil")",
        force: true
      )
    } catch {
      let nsError = error as NSError
      ClerkLogger.info(
        "clerk-watch-sync diag context-error domain=\(nsError.domain) code=\(nsError.code)",
        force: true
      )
      if nsError.domain == "WCErrorDomain", nsError.code == 7006 || nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Failed to sync data to watch app")
    }
  }
}

#if os(iOS)
@MainActor
func createWatchConnectivityManager(
  payloadHandler: @escaping @MainActor (WatchSyncPayload) -> Void,
  activationHandler: @escaping @MainActor () -> Void,
  operationHandler: @escaping @MainActor (Data) async throws -> Data
) -> any WatchConnectivitySyncing {
  WatchConnectivityManager(payloadHandler: payloadHandler, activationHandler: activationHandler, operationHandler: operationHandler)
}
#endif

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(_: WCSession, didReceiveMessageData data: Data, replyHandler: @escaping (Data) -> Void) {
    let reply = WatchOperationReply(call: replyHandler)
    Task { @MainActor in
      do {
        try await reply.call(operationHandler(data))
      } catch {
        let id = (try? JSONDecoder().decode(WatchOperationRequest.self, from: data).id) ?? UUID()
        let response = WatchOperationResponse(id: id, result: nil, apiError: error as? ClerkAPIError, message: error.localizedDescription, state: nil)
        reply.call((try? JSONEncoder().encode(response)) ?? Data())
      }
    }
  }

  nonisolated func session(
    _: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      return
    }

    Task { @MainActor in
      self.isSessionActivated = activationState == .activated
      if self.isSessionActivated {
        self.activationHandler()
        self.syncPendingPayloadIfPossible()
      }
    }
  }

  #if os(iOS)
  nonisolated func sessionDidBecomeInactive(_: WCSession) {
    Task { @MainActor in
      self.isSessionActivated = false
    }
  }

  nonisolated func sessionDidDeactivate(_: WCSession) {
    Task { @MainActor in
      self.session.activate()
    }
  }

  nonisolated func sessionWatchStateDidChange(_: WCSession) {
    Task { @MainActor in
      self.activationHandler()
      self.syncPendingPayloadIfPossible()
    }
  }

  nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    let payload = WatchSyncPayload(applicationContext: applicationContext)

    Task { @MainActor [weak self] in
      guard let self else { return }
      if let payload {
        applyPayload(payload)
      }
    }
  }
  #endif
}

#endif

#if os(iOS)
private struct WatchOperationReply: @unchecked Sendable {
  let call: (Data) -> Void
}
#endif
