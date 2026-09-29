//
//  WatchSyncTransport.swift
//  Clerk
//

import Foundation

@MainActor
protocol WatchSyncTransport: AnyObject {
  func send(_ change: WatchSyncChange)
}

@MainActor
func makePlatformWatchSyncTransport(
  onReceive: @escaping @MainActor (WatchSyncChange) -> Void,
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

/// Sends the latest change with `updateApplicationContext`, which keeps only the most
/// recent value and delivers it even when the counterpart app is not running.
final class WatchConnectivityTransport: NSObject, WatchSyncTransport {
  private let session = WCSession.default
  private let onReceive: @MainActor (WatchSyncChange) -> Void
  private let onActivate: @MainActor () -> Void

  @MainActor private var isActivated = false
  @MainActor private var pendingChange: WatchSyncChange?

  init(
    onReceive: @escaping @MainActor (WatchSyncChange) -> Void,
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
  func send(_ change: WatchSyncChange) {
    pendingChange = change
    sendPendingChangeIfPossible()
  }

  @MainActor
  private func sendPendingChangeIfPossible() {
    guard isActivated, let change = pendingChange else { return }
    #if os(iOS)
    guard session.isPaired, session.isWatchAppInstalled else { return }
    #endif

    do {
      try session.updateApplicationContext(change.applicationContext)
      pendingChange = nil
    } catch {
      guard !Self.isExpectedUnavailability(error) else { return }
      ClerkLogger.logError(error, message: "Failed to send the sign-in state to the paired device")
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

    let received = WatchSyncChange(applicationContext: session.receivedApplicationContext)
    Task { @MainActor [weak self] in
      guard let self else { return }
      isActivated = activationState == .activated
      guard isActivated else { return }
      if let received {
        onReceive(received)
      }
      onActivate()
      sendPendingChangeIfPossible()
    }
  }

  nonisolated func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    guard let change = WatchSyncChange(applicationContext: applicationContext) else { return }
    Task { @MainActor [weak self] in
      self?.onReceive(change)
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
      self?.sendPendingChangeIfPossible()
    }
  }
  #endif
}
#endif
