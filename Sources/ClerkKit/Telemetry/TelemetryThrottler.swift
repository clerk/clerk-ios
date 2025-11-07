//
//  TelemetryThrottler.swift
//  Clerk
//
//  Created by Mike Pitre on 8/8/25.
//

import Foundation

/// An actor that throttles telemetry events to avoid flooding.
///
/// It stores a cache in `UserDefaults` keyed by a stable hash of the event
/// contents. If the same event is recorded within the TTL window, it is
/// considered throttled.
actor TelemetryEventThrottler {
  private let userDefaults: UserDefaults
  private let storageKey = "clerk_telemetry_throttler"
  private let cacheTtl: TimeInterval = 24 * 60 * 60 // 24 hours
  private var memoryCache: [String: TimeInterval]?

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func isEventThrottled(_ event: TelemetryEvent) async -> Bool {
    // Lazily initialize in-memory cache from persistent storage
    if memoryCache == nil {
      memoryCache = loadCache()
      // Clean up expired entries on first access
      cleanupExpiredEntries()
    }

    let now = Date().timeIntervalSince1970
    let key = generateKey(for: event)

    // Work on the in-memory cache for consistency within this actor instance
    var cache = memoryCache ?? [:]
    let entry = cache[key]

    // New entry → write and allow
    guard let lastSeen = entry else {
      cache[key] = now
      memoryCache = cache
      saveCache(cache)
      return false
    }

    // Invalidate if TTL expired
    if now - lastSeen > cacheTtl {
      cache[key] = now // Record new timestamp
      memoryCache = cache
      saveCache(cache)
      return false
    }

    // Otherwise, throttled
    return true
  }

  // MARK: - Private

  private func cleanupExpiredEntries() {
    guard var cache = memoryCache else { return }

    let now = Date().timeIntervalSince1970
    let originalCount = cache.count

    // Remove expired entries
    cache = cache.filter { _, timestamp in
      now - timestamp <= cacheTtl
    }

    // Update cache if any entries were removed
    if cache.count < originalCount {
      memoryCache = cache
      saveCache(cache)
    }
  }

  private func loadCache() -> [String: TimeInterval] {
    guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
    if let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
      return decoded
    }
    return [:]
  }

  private func saveCache(_ cache: [String: TimeInterval]) {
    if let data = try? JSONEncoder().encode(cache) {
      userDefaults.set(data, forKey: storageKey)
    }
  }

  /// Generates a stable key by sorting the event fields and payload.
  func generateKey(for event: TelemetryEvent) -> String {
    var fields: [String] = []
    fields.append("event:\(event.event)")
    fields.append("it:\(event.it)")
    fields.append("sdk:\(event.sdk)")
    fields.append("sdkv:\(event.sdkv)")
    if let pk = event.pk { fields.append("pk:\(pk)") }

    let payloadKey = stableJSONString(event.payload)
    fields.append("payload:\(payloadKey)")

    return fields.sorted().joined(separator: "|")
  }

  private func stableJSONString(_ value: [String: JSON]) -> String {
    // Convert to a stable JSON string with sorted keys
    func encodeJSON(_ value: JSON) -> Any {
      switch value {
      case let .string(s): return s
      case let .number(n): return n
      case let .bool(b): return b
      case .null: return NSNull()
      case let .array(arr): return arr.map(encodeJSON)
      case let .object(obj):
        let sorted = obj.sorted { $0.key < $1.key }
        var dict: [String: Any] = [:]
        for (k, v) in sorted {
          dict[k] = encodeJSON(v)
        }
        return dict
      }
    }

    let sorted = value.sorted { $0.key < $1.key }
    var dict: [String: Any] = [:]
    for (k, v) in sorted {
      dict[k] = encodeJSON(v)
    }

    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else {
      return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
  }
}
