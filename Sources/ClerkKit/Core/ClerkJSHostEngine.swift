import ClerkJSCore
import ClerkSnapshots
import Foundation

@MainActor
final class ClerkJSHostEngine: ClerkEngineClient {
  private let host: ClerkJSHost
  private let kit: Clerk

  init(host: ClerkJSHost, kit: Clerk) {
    self.host = host
    self.kit = kit
  }

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    await ClerkJSHostStore.loadIfNeeded(host, key: kit.publishableKey, onto: kit)
    defer { ClerkJSHostStore.publish(host, onto: kit) }
    do {
      return try await host.invoke(invocation)
    } catch let error as ClerkJSError {
      throw KitJSErrorMapping.kitError(error)
    }
  }
}

@MainActor
package enum ClerkJSHostStore {
  private static var instances: [String: ClerkJSHost] = [:]
  private static var loadTasks: [String: Task<Void, Error>] = [:]

  static func shared(for publishableKey: String) -> ClerkJSHost {
    if let existing = instances[publishableKey] {
      return existing
    }
    let created = ClerkJSHost.persistent(publishableKey: publishableKey)
    instances[publishableKey] = created
    return created
  }

  static func register(_ host: ClerkJSHost, for publishableKey: String, alreadyLoaded: Bool) {
    instances[publishableKey] = host
    if alreadyLoaded {
      loadTasks[publishableKey] = Task {}
    }
  }

  package static func registerPreview(isSignedIn: Bool, publishableKey: String, onto kit: Clerk) {
    let host = ClerkJSHost(publishableKey: publishableKey)
    if let environment = try? ClerkJSHost.snapshotEnvironment() {
      host.publishEnvironment(environment)
    }
    if isSignedIn, let data = try? ClerkJSHost.snapshotSignedInClient() {
      try? host.publishClient(data)
    }
    register(host, for: publishableKey, alreadyLoaded: true)
    publish(host, onto: kit)
  }

  static func loadIfNeeded(_ host: ClerkJSHost, key: String, onto kit: Clerk) async {
    if let existing = loadTasks[key] {
      try? await existing.value
      publish(host, onto: kit)
      return
    }
    let task = Task {
      try await host.load()
    }
    loadTasks[key] = task
    do {
      try await task.value
      publish(host, onto: kit)
    } catch {
      loadTasks[key] = nil
    }
  }

  static func publish(_ host: ClerkJSHost, onto kit: Clerk) {
    if let environment = host.lastEnvironmentJSON {
      do {
        try kit.applyEngineEnvironmentJSON(environment)
      } catch {
        ClerkLogger.logError(error, message: "Failed to apply JS environment")
      }
    }
    guard let data = host.lastClientJSON else { return }
    let payload = (try? FAPIJSON.normalizeClientJSON(data)) ?? data
    try? kit.applyEngineClientJSON(payload, deviceToken: host.lastClientToken)
  }
}

enum KitJSErrorMapping {
  static func kitError(_ error: ClerkJSError) -> any Error {
    switch error.kind {
    case .api:
      var first = error.errors.first ?? ClerkAPIError(
        code: error.code ?? "api_error",
        message: error.message
      )
      if let trace = error.clerkTraceId, first.clerkTraceId.isEmpty {
        first.clerkTraceId = trace
      }
      return first
    case .offline, .runtime, .resolution, .javascript:
      return ClerkClientError(message: String.LocalizationValue(stringLiteral: error.message))
    }
  }
}

extension Clerk {
  @MainActor
  static func installJSHostFactoryIfNeeded() {
    guard makeEngineClient == nil else { return }
    guard !EnvironmentDetection.isRunningInTests else { return }
    #if os(watchOS)
    return
    #else
    makeEngineClient = { kit in
      let host = ClerkJSHostStore.shared(for: kit.publishableKey)
      await ClerkJSHostStore.loadIfNeeded(host, key: kit.publishableKey, onto: kit)
      return ClerkJSHostEngine(host: host, kit: kit)
    }
    #endif
  }
}
