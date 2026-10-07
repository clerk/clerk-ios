@testable import ClerkKit
import Foundation
import Security

/// An in-memory keychain storage implementation for testing.
/// Data is stored in a dictionary and cleared when the test completes.
final class InMemoryKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private var items: [String: Data] = [:]

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }

  var isEmpty: Bool {
    lock.lock()
    defer { lock.unlock() }
    return items.isEmpty
  }
}

final class SetFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case set
  }

  func set(_: Data, forKey _: String) throws {
    throw Failure.set
  }

  func data(forKey _: String) throws -> Data? {
    nil
  }

  func deleteItem(forKey _: String) throws {}

  func hasItem(forKey _: String) throws -> Bool {
    false
  }
}

struct MissingEntitlementKeychain: KeychainStorage {
  private var error: KeychainError {
    .unexpectedStatus(errSecMissingEntitlement)
  }

  func set(_: Data, forKey _: String) throws {
    throw error
  }

  func data(forKey _: String) throws -> Data? {
    throw error
  }

  func deleteItem(forKey _: String) throws {
    throw error
  }

  func hasItem(forKey _: String) throws -> Bool {
    throw error
  }
}

final class ThreadRecordingKeychain: @unchecked Sendable, KeychainStorage {
  private let storage = InMemoryKeychain()
  private let lock = NSLock()
  private var writes: [(key: String, isMainThread: Bool)] = []

  var mainThreadWrites: [String] {
    lock.withLock { writes.filter(\.isMainThread).map(\.key) }
  }

  var backgroundWrites: [String] {
    lock.withLock { writes.filter { !$0.isMainThread }.map(\.key) }
  }

  func set(_ data: Data, forKey key: String) throws {
    record(key)
    try storage.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try storage.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    record(key)
    try storage.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try storage.hasItem(forKey: key)
  }

  private func record(_ key: String) {
    let isMainThread = Thread.isMainThread
    lock.withLock { writes.append((key, isMainThread)) }
  }
}

final class StalledWriteKeychain: @unchecked Sendable, KeychainStorage {
  private let storage = InMemoryKeychain()
  private let writeStarted = DispatchSemaphore(value: 0)
  private let gate = DispatchSemaphore(value: 0)
  private let lock = NSLock()
  private var isReleased = false
  private var setValues: [Data] = []

  var writtenValues: [Data] {
    lock.withLock { setValues }
  }

  func set(_ data: Data, forKey key: String) throws {
    if !lock.withLock({ isReleased }) {
      writeStarted.signal()
      gate.wait()
    }
    lock.withLock { setValues.append(data) }
    try storage.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try storage.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try storage.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try storage.hasItem(forKey: key)
  }

  func waitUntilWriteStarts() async {
    let writeStarted = writeStarted
    await withCheckedContinuation { continuation in
      DispatchQueue.global().async {
        writeStarted.wait()
        continuation.resume()
      }
    }
  }

  func release() {
    lock.withLock { isReleased = true }
    gate.signal()
  }
}
