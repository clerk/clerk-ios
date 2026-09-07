#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import Foundation

@MainActor
final class ClerkJSEngineClient: ClerkEngineClient {
  private let engine: ClerkJSCore.Clerk
  private let kit: ClerkKit.Clerk

  init(engine: ClerkJSCore.Clerk, kit: ClerkKit.Clerk) {
    self.engine = engine
    self.kit = kit
  }

  func invoke(_ invocation: ClerkJSInvocation) async throws -> JSONValue {
    await loadIfNeeded()
    defer { publish() }
    do {
      return try await engine.invoke(invocation)
    } catch let error as ClerkJSError {
      throw KitJSErrorMapping.kitError(error)
    }
  }

  private func loadIfNeeded() async {
    await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
  }

  private func publish() {
    ClerkRuntimeStore.publish(engine, onto: kit)
  }
}

enum KitJSErrorMapping {
  static func kitError(_ error: ClerkJSError) -> any Error {
    switch error.kind {
    case .api:
      let first = error.errors.first
      let meta = first.flatMap(\.meta).flatMap { value in
        (try? JSONEncoder().encode(value)).flatMap { try? JSONDecoder().decode(JSON.self, from: $0) }
      }
      return ClerkKit.ClerkAPIError(
        code: first?.code ?? error.code ?? "api_error",
        message: first?.message ?? error.message,
        longMessage: first?.longMessage,
        meta: meta,
        clerkTraceId: error.clerkTraceId
      )
    case .offline, .runtime, .resolution, .javascript:
      return ClerkClientError(message: String.LocalizationValue(stringLiteral: error.message))
    }
  }
}

@MainActor
enum ClerkEngineBootstrap {
  static func install() {
    guard Clerk.makeEngineClient == nil else { return }
    Clerk.makeEngineClient = { kit in
      let engine = ClerkRuntimeStore.shared(for: kit.publishableKey)
      await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
      return ClerkJSEngineClient(engine: engine, kit: kit)
    }
  }
}

@MainActor
@objc(ClerkEngineBootstrapMarker)
final class ClerkEngineBootstrapMarker: NSObject {
  @objc static func installEngineFactory() {
    ClerkEngineBootstrap.install()
  }
}

#endif
