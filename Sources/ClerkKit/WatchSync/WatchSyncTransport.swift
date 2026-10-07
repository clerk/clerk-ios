//
//  WatchSyncTransport.swift
//  Clerk
//

import Foundation

@MainActor
protocol WatchSyncTransport: AnyObject {
  func send(_ change: WatchSyncChange)
  func stop()
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
///
/// `WCSession` has a single delegate, so this transport takes the place of the app's delegate
/// and forwards every callback to it.
final class WatchConnectivityTransport: NSObject, WatchSyncTransport {
  private let session = WCSession.default
  private nonisolated(unsafe) weak var appDelegate: (any WCSessionDelegate)?
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

    guard WCSession.isSupported() else { return }

    if let previousTransport = session.delegate as? WatchConnectivityTransport {
      appDelegate = previousTransport.appDelegate
    } else {
      appDelegate = session.delegate
    }
    session.delegate = self
    if session.activationState == .activated {
      didActivate(session, activationState: .activated)
    } else {
      session.activate()
    }
  }

  override func responds(to selector: Selector!) -> Bool {
    super.responds(to: selector) || appDelegate?.responds(to: selector) == true
  }

  override func forwardingTarget(for selector: Selector!) -> Any? {
    appDelegate?.responds(to: selector) == true ? appDelegate : nil
  }

  @MainActor
  func send(_ change: WatchSyncChange) {
    pendingChange = change
    sendPendingChangeIfPossible()
  }

  /// Hands the session back to the app's delegate, because `WCSession` holds its delegate
  /// weakly and would otherwise be left with none once this transport is released.
  @MainActor
  func stop() {
    pendingChange = nil
    if session.delegate === self {
      session.delegate = appDelegate
    }
  }

  @MainActor
  private func sendPendingChangeIfPossible() {
    guard isActivated, let change = pendingChange else { return }
    #if os(iOS)
    guard session.isPaired, session.isWatchAppInstalled else { return }
    #endif
    if session.delegate !== self {
      ClerkLogger.error(
        "Another object replaced the WCSession delegate, so this device no longer receives sign-in changes from its paired device. Set your WCSession delegate before configuring Clerk."
      )
    }

    do {
      try session.updateApplicationContext(change.applicationContext(mergedInto: session.applicationContext))
      pendingChange = nil
    } catch {
      guard !Self.isExpectedUnavailability(error) else { return }
      ClerkLogger.logError(error, message: "Failed to send the sign-in state to the paired device")
    }
  }

  private nonisolated func didActivate(_ session: WCSession, activationState: WCSessionActivationState) {
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
    appDelegate?.session(session, activationDidCompleteWith: activationState, error: error)

    if let error {
      if !Self.isExpectedUnavailability(error) {
        ClerkLogger.logError(error, message: "Watch Connectivity session activation failed")
      }
      return
    }

    didActivate(session, activationState: activationState)
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    appDelegate?.session?(session, didReceiveApplicationContext: applicationContext)

    guard let change = WatchSyncChange(applicationContext: applicationContext) else { return }
    Task { @MainActor [weak self] in
      self?.onReceive(change)
    }
  }

  #if os(iOS)
  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    appDelegate?.sessionDidBecomeInactive(session)

    Task { @MainActor [weak self] in
      self?.isActivated = false
    }
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    appDelegate?.sessionDidDeactivate(session)

    session.activate()
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    appDelegate?.sessionWatchStateDidChange?(session)

    Task { @MainActor [weak self] in
      self?.onActivate()
      self?.sendPendingChangeIfPossible()
    }
  }
  #endif
}
#endif
