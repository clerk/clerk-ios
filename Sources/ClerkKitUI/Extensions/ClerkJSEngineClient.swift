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

  func signInWithEmailCode(emailAddress: String) async throws {
    await ClerkRuntimeStore.loadIfNeeded(engine, key: kit.publishableKey, onto: kit)
    _ = try await engine.client.signIn.create(
      .init(identifier: emailAddress, strategy: "email_code")
    )
    ClerkRuntimeStore.publish(engine, onto: kit)
  }

  func sendEmailCode(emailAddressId: String?) async throws {
    _ = try await engine.client.signIn.prepareFirstFactor(
      .init(strategy: .emailCode, emailAddressId: emailAddressId)
    )
    ClerkRuntimeStore.publish(engine, onto: kit)
  }

  func verifyEmailCode(_ code: String) async throws {
    let signIn = try await engine.client.signIn.attemptFirstFactor(
      .init(strategy: .emailCode, code: code)
    )
    if signIn.status == .complete, let sessionId = signIn.createdSessionId {
      try await engine.setActive(.init(session: sessionId))
    }
    ClerkRuntimeStore.publish(engine, onto: kit)
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
