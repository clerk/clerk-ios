#if !os(watchOS)
import ClerkJSCore
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

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)
    try await deferCleanup(runtime, email: email) {
    let created = try await catchClerkCall(
      runtime,
      methodPath: "__clerkInstance.client.signIn.create",
      args: ["identifier": email]
    )
    if !created.ok, try wireField(fapiClientObject(runtime), "sign_in") != "object" {
      Issue.record("FAPI \(created.errors.first?.code ?? "sign_in_create")")
      return
    }
    if let code = try instanceCannotEmailCode(fapiClientObject(runtime)) {
      Issue.record("FAPI \(code)")
      return
    }

    let prepared = try await callSignInMethod(
      runtime,
      methodName: "prepareFirstFactor",
      args: emailCodeFactorArgs(fapiClientObject(runtime))
    )
    if !prepared.ok, try wireField(fapiClientObject(runtime), "sign_in") != "object" {
      Issue.record("FAPI \(prepared.errors.first?.code ?? "sign_in_prepare")")
      return
    }

    let attempted = try await callSignInMethod(
      runtime,
      methodName: "attemptFirstFactor",
      args: ["strategy": "email_code", "code": "424242"]
    )
    if !attempted.ok, !fapiHasSession(runtime) {
      Issue.record("FAPI \(attempted.errors.first?.code ?? "attempt_failed")")
      return
    }

    let completed = try readGeneratedSignIn(runtime)
    let sessionId = try #require(fapiSessionID(runtime) ?? completed.createdSessionId)
    #expect(sessionId.hasPrefix("sess_"))

    let probe = try await jsSessionProbe(runtime)
    do {
      _ = try await runtime.call(
        methodPath: "__clerkInstance.setActive",
        args: ["session": sessionId]
      )
      let tokenJSON = try await runtime.call(
        methodPath: "__clerkInstance.session.getToken",
        args: [String: String]()
      )
      let token = try JSONDecoder().decode(String.self, from: Data(tokenJSON.utf8))
      #expect(token.count > 4)
    } catch {
      if probe.sessionCount == 0, let payload = runtime.lastFAPIClientJSON {
        let applied = try await applyFAPIClientJSON(runtime, payload: payload)
        Issue.record("fromJSON ok=\(applied.ok) \(applied.errorCode) count=\(applied.sessionCount)")
      }
      Issue.record(
        "setActive \(sanitizedJSError(error)) sessions=\(probe.sessionCount) session=\(probe.clerkSessionType) getToken=\(probe.getTokenType)"
      )
      throw error
    }
    #expect(probe.sessionCount >= 1)
    #expect(probe.sessionIdPrefixes.contains { $0 == "sess_" })
    }
    }
  }
}

private struct JSSessionProbe: Decodable {
  var sessionCount: Int
  var sessionIdPrefixes: [String]
  var lastActivePrefix: String?
  var createdSessionPrefix: String?
  var clerkSessionType: String
  var getTokenType: String
}

private func jsSessionProbe(_ runtime: ClerkJSRuntime) async throws -> JSSessionProbe {
  try await JSONDecoder().decode(
    JSSessionProbe.self,
    from: Data(
      (
        runtime.evaluateJSON(
          """
          (function() {
            var client = globalThis.__clerkInstance.client;
            var sessions = client.sessions || [];
            return {
              sessionCount: sessions.length,
              sessionIdPrefixes: sessions.map(function(s) {
                return typeof s.id === 'string' ? s.id.slice(0, 5) : '';
              }),
              lastActivePrefix: client.lastActiveSessionId
                ? String(client.lastActiveSessionId).slice(0, 5)
                : null,
              createdSessionPrefix: client.signIn && client.signIn.createdSessionId
                ? String(client.signIn.createdSessionId).slice(0, 5)
                : null,
              clerkSessionType: typeof globalThis.__clerkInstance.session,
              getTokenType: globalThis.__clerkInstance.session
                ? typeof globalThis.__clerkInstance.session.getToken
                : 'null_session'
            };
          })()
          """
        )
      ).utf8
    )
  )
}

private struct AppliedClientJSON: Decodable {
  var ok: Bool
  var errorCode: String
  var sessionCount: Int
}

private func applyFAPIClientJSON(_ runtime: ClerkJSRuntime, payload: Data) async throws -> AppliedClientJSON {
  let json = String(data: payload, encoding: .utf8) ?? "null"
  let script = """
    (function() {
      try {
        var client = globalThis.__clerkInstance.client;
        client.fromJSON(\(json));
        return {
          ok: true,
          errorCode: "",
          sessionCount: (client.sessions || []).length
        };
      } catch (e) {
        var code = e && e.name ? String(e.name) : 'js_error';
        if (e && typeof e.message === 'string') {
          code = code + ':' + e.message.slice(0, 80);
        }
        return { ok: false, errorCode: code, sessionCount: 0 };
      }
    })()
    """
  return try await JSONDecoder().decode(
    AppliedClientJSON.self,
    from: Data((runtime.evaluateJSON(script)).utf8)
  )
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

private func wireField(_ object: [String: Any], _ key: String) -> String {
  guard object.keys.contains(key) else {
    return "missing"
  }
  switch object[key] {
  case nil, is NSNull:
    return "null"
  case is [String: Any]:
    return "object"
  default:
    return "other"
  }
}
#endif
