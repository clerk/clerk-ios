//
//  SharedSessionSyncNotifier.swift
//  Clerk
//

import Foundation

@MainActor
protocol SharedSessionSyncNotifying: AnyObject {
  func setHandler(_ handler: @escaping @MainActor () -> Void)
  func post()
}

@MainActor
final class SharedSessionSyncDarwinNotifier: SharedSessionSyncNotifying {
  private let notificationName: CFNotificationName
  private var handler: (@MainActor () -> Void)?

  init(
    keychainConfig: Clerk.Options.KeychainConfig,
    instanceFingerprint: String
  ) {
    notificationName = CFNotificationName(Self.notificationName(
      for: keychainConfig,
      instanceFingerprint: instanceFingerprint
    ) as CFString)
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      sharedSessionSyncDarwinNotificationCallback,
      notificationName.rawValue,
      nil,
      .deliverImmediately
    )
  }

  deinit {
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      notificationName,
      nil
    )
  }

  func setHandler(_ handler: @escaping @MainActor () -> Void) {
    self.handler = handler
  }

  func post() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      notificationName,
      nil,
      nil,
      true
    )
  }

  nonisolated func notify() {
    Task { @MainActor [weak self] in
      self?.handler?()
    }
  }

  static func notificationName(
    for keychainConfig: Clerk.Options.KeychainConfig,
    instanceFingerprint: String = ""
  ) -> String {
    let seed = "\(keychainConfig.service)\u{1F}\(keychainConfig.normalizedAccessGroup ?? "")\u{1F}\(instanceFingerprint)"
    return "com.clerk.shared-session-sync.\(SharedSessionNamespace.sha256(seed))"
  }
}

private let sharedSessionSyncDarwinNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
  guard let observer else { return }
  let notifier = Unmanaged<SharedSessionSyncDarwinNotifier>.fromOpaque(observer).takeUnretainedValue()
  notifier.notify()
}
