//
//  KeychainWriteQueue.swift
//  Clerk
//

import Foundation

/// Keychain calls wait on `securityd` over XPC and can take seconds, so they must stay off
/// the main thread. The exception is the file-based macOS keychain, which deadlocks when two
/// threads call it at once; there `writesOnCallingThread` keeps writes on the caller's thread
/// (see `DependencyContainer.makeCacheWrites()`).
final class KeychainWriteQueue: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.clerk.keychain-writes", qos: .userInitiated)
  private let lock = NSLock()
  private var pendingWrites: [ClerkKeychainKey: @Sendable () -> Void] = [:]
  private var pauseCount = 0
  let writesOnCallingThread: Bool

  init(writesOnCallingThread: Bool = false) {
    self.writesOnCallingThread = writesOnCallingThread
  }

  func enqueue(_ key: ClerkKeychainKey, _ write: @escaping @Sendable () -> Void) {
    guard !writesOnCallingThread else {
      write()
      return
    }
    let shouldSchedule = lock.withLock {
      pendingWrites.updateValue(write, forKey: key) == nil
    }
    if shouldSchedule {
      schedule(key)
    }
  }

  func pauseWrites() {
    lock.withLock { pauseCount += 1 }
  }

  func resumeWrites() {
    let heldKeys = lock.withLock {
      pauseCount -= 1
      return pauseCount == 0 ? Array(pendingWrites.keys) : []
    }
    heldKeys.forEach(schedule)
  }

  func writeNow(_ key: ClerkKeychainKey, _ write: () -> Void) {
    lock.withLock { _ = pendingWrites.removeValue(forKey: key) }
    queue.sync(execute: write)
  }

  func discardPendingWrites() {
    lock.withLock { pendingWrites.removeAll() }
    queue.sync {}
  }

  func waitForPendingWrites() async {
    await withCheckedContinuation { continuation in
      queue.async { continuation.resume() }
    }
  }

  private func schedule(_ key: ClerkKeychainKey) {
    queue.async { [self] in
      let write = lock.withLock { pauseCount == 0 ? pendingWrites.removeValue(forKey: key) : nil }
      write?()
    }
  }
}
