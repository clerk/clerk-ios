//
//  E2ECleanupCommand.swift
//  E2EHost
//

import Foundation

enum E2ECleanupCommand {
  static let notificationName = "com.clerk.E2EHost.cleanupAccount"

  static func startObserving() {
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      nil,
      { _, _, _, _, _ in
        Task { @MainActor in
          NotificationCenter.default.post(name: .e2eCleanupAccountRequested, object: nil)
        }
      },
      notificationName as CFString,
      nil,
      .deliverImmediately
    )
  }
}

extension Notification.Name {
  static let e2eCleanupAccountRequested = Notification.Name("com.clerk.E2EHost.cleanupAccount.requested")
}
