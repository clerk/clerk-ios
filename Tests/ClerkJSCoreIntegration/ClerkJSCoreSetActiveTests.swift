#if !os(watchOS)
@testable import ClerkJSCore
import ClerkWatchCompanion
import Foundation
import Testing

struct ClerkJSCoreSetActiveTests {
  @Test
  func emailCodeSetActiveReturnsSessionToken() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let signUpRuntime = ClerkJSRuntime()
    try await signUpRuntime.load(publishableKey: publishableKey)
    let hasClientJWT = try await decodeJSONBool(
      signUpRuntime.evaluateJSON(
        "(async function(){ var t = await __clerkNativeGetToken(); return t.length > 0; })()"
      )
    )
    if !hasClientJWT {
      Issue.record("FAPI missing_client_jwt")
      return
    }

    try await FAPITestGate.shared.run {
    let email = uniqueClerkTestEmail()
    if let code = await ensureSignedUpUser(signUpRuntime, email: email) {
      _ = await deleteCreatedTestUser(signUpRuntime, email: email)
      Issue.record("FAPI \(code)")
      return
    }

    try await deferCleanup(signUpRuntime, email: email) {
    let service = "com.clerk.jscore.\(ClerkJSHost.storageNamespace(for: publishableKey))"
    let keychain = ClerkJSKeychain(service: service)
    try? keychain.delete(account: "client-jwt")
    try? keychain.delete(account: "client-snapshot")
    try? keychain.delete(account: "environment-snapshot")

    let clerk = await ClerkJSHost.persistent(publishableKey: publishableKey)
    try await clerk.load()
    try await deferCleanup(clerk.runtime, email: email) {
    let created: ClerkJSHost.SignIn
    do {
      created = try await clerk.client.signIn.create(.init(identifier: email))
    } catch {
      Issue.record("FAPI \(sanitizedJSError(error))")
      return
    }
    if await created.id == nil {
      Issue.record("FAPI sign_in_create")
      return
    }
    let factors = await created.supportedFirstFactors
    if let code = emailCodeUnsupported(factors) {
      Issue.record("FAPI \(code)")
      return
    }

    let emailAddressId = factors.first { $0.strategy == "email_code" }?.emailAddressId
    do {
      try await created.prepareFirstFactor(.init(strategy: "email_code", emailAddressId: emailAddressId))
    } catch {
      Issue.record(
        "FAPI \(sanitizedJSError(error)) factors=\(factors.count) emailId=\(emailAddressId != nil)"
      )
      return
    }

    let attempted: ClerkJSHost.SignIn
    do {
      attempted = try await created.attemptFirstFactor(.init(strategy: .emailCode, code: "424242"))
    } catch {
      if await clerk.client.signIn.createdSessionId == nil, await clerk.client.lastActiveSessionId == nil {
        Issue.record("FAPI \(sanitizedJSError(error))")
        return
      }
      throw error
    }

    let createdSessionId = await attempted.createdSessionId
    let lastActiveSessionId = await clerk.client.lastActiveSessionId
    let sessionId = try #require(createdSessionId ?? lastActiveSessionId)
    #expect(sessionId.hasPrefix("sess_"))

    do {
      try await clerk.setActive(.init(session: sessionId))
      let token = try await clerk.session.getToken()
      #expect((token ?? "").count > 4)
      let skipped = try await clerk.session.getToken(.init(skipCache: true))
      #expect((skipped ?? "").count > 4)
      let invoked = try await clerk.invoke(
        ClerkJSInvocation(
          .session(id: ClerkJSResourceID(sessionId)),
          SessionJSCall.getToken(GetTokenOptions(skipCache: true))
        )
      )
      guard case .string(let jwt) = invoked else {
        Issue.record("invoke skipCache getToken did not return a string")
        return
      }
      #expect(jwt.count > 4)
      var replica = WatchCompanion()
      try await replica.apply(clerk.watchCompanion.encode())
      #expect(replica.client?.id.hasPrefix("client_") == true)
      #expect(replica.client?.lastActiveSessionId == sessionId)
    } catch {
      Issue.record("setActive \(sanitizedJSError(error))")
      throw error
    }
    }
    }
    }
  }
}

private func emailCodeUnsupported(_ factors: [SignInFirstFactor]) -> String? {
  let strategies = factors.map(\.strategy)
  if !strategies.isEmpty, !strategies.contains("email_code") {
    return "email_code_unsupported"
  }
  return nil
}

private func sanitizedJSError(_ error: Error) -> String {
  let raw: String = if let clerkError = error as? ClerkJSCoreError, case .javascript(let message) = clerkError {
    message
  } else {
    String(describing: error)
  }
  return raw
    .replacingOccurrences(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, with: "<email>", options: [.regularExpression, .caseInsensitive])
    .replacingOccurrences(of: #"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"#, with: "<jwt>", options: .regularExpression)
    .replacingOccurrences(of: #"\+[0-9]{10,15}"#, with: "<phone>", options: .regularExpression)
}
#endif
