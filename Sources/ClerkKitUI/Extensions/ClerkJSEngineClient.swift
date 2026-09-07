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

  func startSessionVerification(level: String) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.startVerification(.init(level: level))
    publish()
    return try decodeSessionVerification(data)
  }

  func prepareSessionFirstFactor(
    strategy: String,
    emailAddressId: String?,
    phoneNumberId: String?,
    enterpriseConnectionId: String?,
    redirectUrl: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.prepareFirstFactorVerification(
      .init(
        strategy: strategy,
        emailAddressId: emailAddressId,
        phoneNumberId: phoneNumberId,
        enterpriseConnectionId: enterpriseConnectionId,
        redirectUrl: redirectUrl
      )
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func attemptSessionFirstFactor(
    strategy: String,
    code: String?,
    password: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.attemptFirstFactorVerification(
      .init(
        strategy: strategy,
        code: code,
        password: password,
        publicKeyCredential: publicKeyCredential
      )
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func prepareSessionSecondFactor(strategy: String, phoneNumberId: String?) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.prepareSecondFactorVerification(
      .init(strategy: strategy, phoneNumberId: phoneNumberId)
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func attemptSessionSecondFactor(
    strategy: String,
    code: String?,
    publicKeyCredential: String?
  ) async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.attemptSecondFactorVerification(
      .init(strategy: strategy, code: code, publicKeyCredential: publicKeyCredential)
    )
    publish()
    return try decodeSessionVerification(data)
  }

  func verifySessionWithPasskey() async throws -> SessionVerification {
    await loadIfNeeded()
    let data = try await engine.session.verifyWithPasskey()
    publish()
    return try decodeSessionVerification(data)
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

  private func decodeSessionVerification(_ data: Data) throws -> SessionVerification {
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ClerkClientError(message: "Session verification did not return a JSON object.")
    }

    object.removeValue(forKey: "session")
    if let status = object["status"] as? String {
      object["status"] = sessionVerificationStatusValue(status)
    }
    if let level = object["level"] as? String {
      object["level"] = sessionVerificationLevelValue(level)
    }
    normalizeFactorVerification(&object, camel: "firstFactorVerification", snake: "first_factor_verification")
    normalizeFactorVerification(&object, camel: "secondFactorVerification", snake: "second_factor_verification")

    let payload = try JSONSerialization.data(withJSONObject: object)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .millisecondsSince1970
    var verification = try decoder.decode(SessionVerification.self, from: payload)
    if verification.session == nil {
      verification.session = kit.session
    }
    return verification
  }

  private func normalizeFactorVerification(
    _ object: inout [String: Any],
    camel: String,
    snake: String
  ) {
    for key in [camel, snake] {
      guard var verification = object[key] as? [String: Any] else { continue }
      if let millis = unixMilliseconds(verification["expireAt"] ?? verification["expire_at"]) {
        verification["expireAt"] = millis
        verification["expire_at"] = millis
      }
      if let nonceObject = verification["nonce"] as? [String: Any],
        let nonceData = try? JSONSerialization.data(withJSONObject: nonceObject),
        let nonceString = String(data: nonceData, encoding: .utf8)
      {
        verification["nonce"] = nonceString
      }
      object[key] = verification
    }
  }

  private func sessionVerificationStatusValue(_ raw: String) -> String {
    switch raw {
    case "needsFirstFactor":
      "needs_first_factor"
    case "needsSecondFactor":
      "needs_second_factor"
    default:
      raw
    }
  }

  private func sessionVerificationLevelValue(_ raw: String) -> String {
    switch raw {
    case "firstFactor":
      "first_factor"
    case "secondFactor":
      "second_factor"
    case "multiFactor":
      "multi_factor"
    default:
      raw
    }
  }

  private func unixMilliseconds(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
      return number.doubleValue
    case let string as String:
      let withFractional = ISO8601DateFormatter()
      withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let date = withFractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
      return date.map { $0.timeIntervalSince1970 * 1000 }
    default:
      return nil
    }
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
