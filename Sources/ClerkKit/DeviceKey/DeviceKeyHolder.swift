//
//  DeviceKeyHolder.swift
//  Clerk
//

import Foundation

final class DeviceKeyHolder: @unchecked Sendable {
  private let store: any DeviceKeyStore
  private let operationLock = NSLock()
  private let stateLock = NSLock()
  private var recorded: DeviceKeyState?

  init(store: any DeviceKeyStore) {
    self.store = store
  }

  var loadedState: DeviceKeyState? {
    stateLock.withLock { recorded }
  }

  func state() -> DeviceKeyState {
    operationLock.withLock { loadedState ?? load() }
  }

  func withKey<T>(_ operation: (any DeviceKey) throws -> T) -> Result<T, any Error> {
    operationLock.withLock {
      let state = loadedState ?? load()
      let result = state.attempt(operation)
      guard case .ready = state, case .failure = result, storedKeyIsGone() else {
        return result
      }
      ClerkLogger.warning("Device key: the keychain no longer holds the key, replacing it")
      let retried = replaceLostKey().attempt(operation)
      if case let .failure(error) = retried, storedKeyIsGone() {
        record(.unavailable(error))
      }
      return retried
    }
  }

  func deleteKey() throws {
    try operationLock.withLock {
      try store.delete()
      stateLock.withLock { recorded = nil }
    }
  }

  private func load() -> DeviceKeyState {
    do {
      return try record(.ready(store.loadOrCreate()))
    } catch {
      return record(.unavailable(error))
    }
  }

  private func replaceLostKey() -> DeviceKeyState {
    do {
      try store.delete()
    } catch {
      return record(.unavailable(error))
    }
    return load()
  }

  private func storedKeyIsGone() -> Bool {
    (try? store.hasStoredKey()) == false
  }

  @discardableResult
  private func record(_ next: DeviceKeyState) -> DeviceKeyState {
    switch next {
    case let .ready(key):
      ClerkLogger.info("Device key ready level=\(key.securityLevel.wireName)")
    case let .unavailable(error):
      ClerkLogger.warning("Device key unavailable: \(error)")
    }
    stateLock.withLock { recorded = next }
    return next
  }
}

extension DeviceKeyState {
  fileprivate func attempt<T>(_ operation: (any DeviceKey) throws -> T) -> Result<T, any Error> {
    switch self {
    case let .ready(key):
      Result { try operation(key) }
    case let .unavailable(error):
      .failure(error)
    }
  }
}
