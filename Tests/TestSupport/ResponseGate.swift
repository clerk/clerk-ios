import Foundation

/// Holds stubbed responses until a test opens their key, so tests can control the order requests finish in.
@MainActor
final class ResponseGate {
  private var continuations: [String: [CheckedContinuation<Void, Never>]] = [:]
  private var opened: Set<String> = []

  func wait(_ key: String) async {
    guard !opened.contains(key) else { return }
    await withCheckedContinuation { continuations[key, default: []].append($0) }
  }

  func open(_ key: String) {
    opened.insert(key)
    for continuation in continuations.removeValue(forKey: key) ?? [] {
      continuation.resume()
    }
  }
}
