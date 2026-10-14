//
//  SharedIdentityNotifier.swift
//  Clerk
//

import Foundation
import notify

@MainActor
final class SharedIdentityNotifier: ClerkInternalStateChangeObserver {
  private let name: String
  private let senderID = UInt64.random(in: 1 ... UInt64.max)
  private weak var clerk: Clerk?
  private var registration = NOTIFY_TOKEN_INVALID
  private var refreshTask: Task<Void, Never>?
  private var isPostScheduled = false

  init(name: String, clerk: Clerk) {
    self.name = name
    self.clerk = clerk
    let senderID = senderID
    notify_register_dispatch(name, &registration, .main) { [weak self] registration in
      var sender: UInt64 = 0
      notify_get_state(registration, &sender)
      guard sender != senderID else { return }
      MainActor.assumeIsolated {
        self?.otherAppDidChange()
      }
    }
  }

  func stop() {
    notify_cancel(registration)
    registration = NOTIFY_TOKEN_INVALID
    refreshTask?.cancel()
    refreshTask = nil
  }

  func handle(_ change: ClerkInternalStateChange, from _: Clerk) throws {
    switch change {
    case .clientDidChange(let previous, let current):
      guard Client.differsIgnoringSessionTokens(previous, current) else { return }
      notifyOtherApps()
    case .identityDidChange, .localStorageDidClear:
      notifyOtherApps()
    case .deviceTokenDidChange, .environmentDidChange, .applicationDidEnterForeground:
      break
    }
  }

  private func notifyOtherApps() {
    guard refreshTask == nil, registration != NOTIFY_TOKEN_INVALID, !isPostScheduled else { return }
    isPostScheduled = true
    DispatchQueue.main.async { [weak self] in
      MainActor.assumeIsolated {
        self?.post()
      }
    }
  }

  private func post() {
    isPostScheduled = false
    guard registration != NOTIFY_TOKEN_INVALID else { return }
    notify_set_state(registration, senderID)
    notify_post(name)
  }

  private func otherAppDidChange() {
    guard clerk != nil, refreshTask == nil else { return }
    refreshTask = clerk?.runtime.scheduleTask { [weak self] in
      await self?.refresh()
    }
  }

  private func refresh() async {
    defer { refreshTask = nil }
    guard let clerk else { return }
    clerk.identityController.adoptStoredDeviceToken()
    guard clerk.deviceToken != nil else { return }
    do {
      try await clerk.refreshClient()
    } catch is CancellationError {
    } catch {
      ClerkLogger.logError(error, message: "Failed to refresh the client after another app changed it")
    }
  }
}
