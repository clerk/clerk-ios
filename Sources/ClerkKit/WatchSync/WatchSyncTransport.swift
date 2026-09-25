//
//  WatchSyncTransport.swift
//  Clerk
//

import Foundation

/// Moves ``WatchSyncPayload`` values between the phone and watch apps.
@MainActor
protocol WatchSyncTransport: AnyObject {
  func send(_ payload: WatchSyncPayload)
}

@MainActor
func makePlatformWatchSyncTransport(
  onReceive: @escaping @MainActor (WatchSyncPayload, WatchSyncSource) -> Void,
  onActivate: @escaping @MainActor () -> Void
) -> (any WatchSyncTransport)? {
  #if os(iOS) || os(watchOS)
  WatchConnectivityTransport(onReceive: onReceive, onActivate: onActivate)
  #else
  nil
  #endif
}

#if os(iOS) || os(watchOS)
import WatchConnectivity

/// Sends the latest payload with `updateApplicationContext`, which keeps only the most
/// recent value and delivers it even when the counterpart app is not running.
final class WatchConnectivityTransport: NSObject, WatchSyncTransport {
  private let session = WCSession.default
  private let onReceive: @MainActor (WatchSyncPayload, WatchSyncSource) -> Void
  private let onActivate: @MainActor () -> Void

  @MainActor private var isActivated = false
  @MainActor private var pendingPayload: WatchSyncPayload?

  #if os(iOS)
  private nonisolated static let peer = WatchSyncSource.watch
  #else
  private nonisolated static let peer = WatchSyncSource.phone
  #endif

  init(
    onReceive: @escaping @MainActor (WatchSyncPayload, WatchSyncSource) -> Void,
    onActivate: @escaping @MainActor () -> Void
  ) {
    self.onReceive = onReceive
    self.onActivate = onActivate
    super.init()

    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  @MainActor
  func send(_ payload: WatchSyncPayload) {
    pendingPayload = payload
    sendPendingPayloadIfPossible()
  }

  @MainActor
  private func sendPendingPayloadIfPossible() {
    guard isActivated, let payload = pendingPayload else { return }
    #if os(iOS)
    guard session.isPaired, session.isWatchAppInstalled else { return }
    #endif

    do {
      try session.updateApplicationContext(payload.applicationContext)
      pendingPayload = nil
    } catch {
      guard !Self.isExpectedUnavailability(error) else { return }
      ClerkLogger.logError(error, message: "Failed to sync Clerk auth state to the paired device")
    }
  }

  private nonisolated static func isExpectedUnavailability(_ error: Error) -> Bool {
    let error = error as NSError
    return error.domain == WCErrorDomain
      && [WCError.sessionNotActivated.rawValue, WCError.watchAppNotInstalled.rawValue].contains(error.code)
  }
}

extension WatchConnectivityTransport: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if let error {
      if !Self.isExpectedUnavailability(error) {
        ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      }
      return
    }

    #if os(watchOS)
    // The watch may have missed the phone's latest context while it wasn't running.
    let received = WatchSyncPayload(applicationContext: session.receivedApplicationContext)
    #else
    let received: WatchSyncPayload? = nil
    #endif

    Task { @MainActor [weak self] in
      guard let self else { return }
      isActivated = activationState == .activated
      guard isActivated else { return }
      if let received {
        onReceive(received, Self.peer)
      }
      onActivate()
      sendPendingPayloadIfPossible()
    }
  }

  nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    guard let payload = WatchSyncPayload(applicationContext: applicationContext) else { return }
    Task { @MainActor [weak self] in
      self?.onReceive(payload, Self.peer)
    }
  }

  #if os(iOS)
  nonisolated func sessionDidBecomeInactive(_: WCSession) {
    Task { @MainActor [weak self] in
      self?.isActivated = false
    }
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  nonisolated func sessionWatchStateDidChange(_: WCSession) {
    Task { @MainActor [weak self] in
      self?.onActivate()
      self?.sendPendingPayloadIfPossible()
    }
  }
  #endif
}
#endif
