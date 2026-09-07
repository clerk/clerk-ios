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

  func authenticateWithRedirect(strategy: String, redirectUrl: String, identifier: String?) async throws {
    await loadIfNeeded()
    try await engine.client.signIn.authenticateWithRedirect(
      .init(strategy: strategy, redirectUrl: resolvedRedirectUrl(redirectUrl), identifier: identifier)
    )
    try await activateIfCompleteAfterRedirect()
  }

  func authenticateSignUpWithRedirect(strategy: String, redirectUrl: String, emailAddress: String?) async throws {
    await loadIfNeeded()
    try await engine.client.signUp.authenticateWithRedirect(
      .init(strategy: strategy, redirectUrl: resolvedRedirectUrl(redirectUrl), emailAddress: emailAddress)
    )
    try await activateIfCompleteAfterRedirect()
  }

  func authenticateWithPasskey(autofill: Bool) async throws {
    await loadIfNeeded()
    let signIn = try await engine.client.signIn.authenticateWithPasskey(
      AuthenticateWithPasskeyParams(flow: autofill ? .autofill : nil)
    )
    try await activateIfComplete(signIn)
  }

  private func loadIfNeeded() async {
    await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
  }

  private func publish() {
    ClerkRuntimeStore.publish(engine, onto: kit)
  }

  private func activateIfComplete(_ signIn: ClerkJSCore.Clerk.SignIn) async throws {
    if signIn.status == .complete, let sessionId = signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func activateIfCompleteAfterRedirect() async throws {
    if let sessionId = engine.client.signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    } else if let sessionId = engine.client.signUp.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    publish()
  }

  private func resolvedRedirectUrl(_ redirectUrl: String) -> String {
    if redirectUrl.isEmpty {
      return ClerkJSRuntime.defaultOAuthRedirectURL.absoluteString
    }
    return redirectUrl
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
