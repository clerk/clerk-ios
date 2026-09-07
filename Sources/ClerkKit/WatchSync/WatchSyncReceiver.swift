//
//  WatchSyncReceiver.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

#if os(watchOS)
import WatchConnectivity

/// Manages receiving synced authentication state (deviceToken, Client, Environment) from the companion iOS app via Watch Connectivity.
///
/// This receiver listens for updates from the iOS app and stores them in the watch app's keychain.
/// For Client, it implements conflict resolution using timestamps (iOS takes priority).
final class WatchSyncReceiver: NSObject, WatchConnectivitySyncing {
  /// The WCSession instance used for communication.
  private let session: WCSession

  private let payloadHandler: @MainActor (WatchSyncPayload) -> Void
  private let activationHandler: @MainActor () -> Void

  /// Whether we're currently processing a sync to prevent loops. Must be accessed from MainActor.
  @MainActor
  private var isProcessingSync = false

  /// Creates a new Watch Sync Receiver.
  init(
    payloadHandler: @escaping @MainActor (WatchSyncPayload) -> Void,
    activationHandler: @escaping @MainActor () -> Void
  ) {
    session = WCSession.default
    self.payloadHandler = payloadHandler
    self.activationHandler = activationHandler
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  @MainActor
  package func requestOperation(_ data: Data) async throws -> Data {
    guard session.activationState == .activated, session.isReachable else {
      throw ClerkClientError(message: "Open the paired iPhone app to use this Clerk operation.")
    }
    let pending = WatchMessagePendingReply()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending.continuation = continuation
        guard !Task.isCancelled else { pending.finish(.failure(CancellationError())); return }
        pending.timeout = Task { @MainActor in
          do {
            try await Task.sleep(for: .seconds(30))
            pending.finish(.failure(URLError(.timedOut)))
          } catch {}
        }
        session.sendMessageData(data, replyHandler: { reply in
          Task { @MainActor in pending.finish(.success(reply)) }
        }, errorHandler: { error in
          Task { @MainActor in pending.finish(.failure(error)) }
        })
      }
    } onCancel: {
      Task { @MainActor in pending.finish(.failure(CancellationError())) }
    }
  }

  @MainActor
  private func applyPayload(_ payload: WatchSyncPayload) {
    isProcessingSync = true
    defer { isProcessingSync = false }
    payloadHandler(payload)
  }

  /// Sends Clerk's reduced watch-sync payload to the iOS app.
  @MainActor
  package func sync(_ payload: WatchSyncPayload) {
    guard !isProcessingSync else { return }
    guard session.activationState == .activated else { return }

    let applicationContext = payload.applicationContext

    guard !applicationContext.isEmpty else { return }

    do {
      try session.updateApplicationContext(applicationContext)
    } catch {
      let nsError = error as NSError
      if nsError.domain == "WCErrorDomain", nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Failed to sync data to iOS app")
    }
  }
}

extension WatchSyncReceiver: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      let nsError = error as NSError
      if nsError.domain == "WCErrorDomain", nsError.code == 7001 {
        return
      }
      ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      return
    }

    let payload = WatchSyncPayload(applicationContext: session.receivedApplicationContext)
    Task { @MainActor [weak self] in
      guard let self else { return }
      if activationState == .activated, let payload {
        applyPayload(payload)
      }
      if activationState == .activated {
        activationHandler()
      }
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
}

#endif

#if os(watchOS)
@MainActor
private final class WatchMessagePendingReply {
  var continuation: CheckedContinuation<Data, Error>?
  var timeout: Task<Void, Never>?

  func finish(_ result: Result<Data, Error>) {
    let continuation = continuation
    self.continuation = nil
    timeout?.cancel()
    timeout = nil
    continuation?.resume(with: result)
  }
}
#endif
