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

  init(keychainConfig: Clerk.Options.KeychainConfig) {
    notificationName = CFNotificationName(Self.notificationName(for: keychainConfig) as CFString)
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

  static func notificationName(for keychainConfig: Clerk.Options.KeychainConfig) -> String {
    let seed = "\(keychainConfig.service)\u{1F}\(keychainConfig.accessGroup ?? "")"
    return "com.clerk.shared-session-sync.\(stableFingerprint(for: seed))"
  }

  private static func stableFingerprint(for value: String) -> String {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x0100_0000_01B3
    }
    return String(hash, radix: 16)
  }
}

private let sharedSessionSyncDarwinNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
  guard let observer else { return }
  let notifier = Unmanaged<SharedSessionSyncDarwinNotifier>.fromOpaque(observer).takeUnretainedValue()
  notifier.notify()
}
