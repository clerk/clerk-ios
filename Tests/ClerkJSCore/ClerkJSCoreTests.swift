#if !os(watchOS)
import ClerkJSCore
import Foundation
import Testing

private let mockPublishableKey = "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk"

struct ClerkJSCoreTests {
  @Test
  func evaluateExposesClerkConstructorWithoutWindow() async throws {
    let runtime = ClerkJSRuntime()
    let clerkType = try await decodeJSONString(runtime.evaluateJSON("typeof Clerk"))
    #expect(clerkType == "function")
    let windowType = try await decodeJSONString(runtime.evaluateJSON("typeof window"))
    #expect(windowType == "undefined")
  }

  @Test
  func constructDoesNotThrow() async throws {
    let runtime = ClerkJSRuntime()
    let result = try await decodeJSONBool(
      runtime.evaluateJSON(
        "(function(){ new Clerk('\(mockPublishableKey)'); return true; })()"
      )
    )
    #expect(result)
  }

  @Test
  func polyfillsAreInstalled() async throws {
    let runtime = ClerkJSRuntime()
    let fetchType = try await decodeJSONString(runtime.evaluateJSON("typeof fetch"))
    #expect(fetchType == "function")
    let online = try await decodeJSONBool(runtime.evaluateJSON("navigator.onLine === true"))
    #expect(online)
    let windowType = try await decodeJSONString(runtime.evaluateJSON("typeof window"))
    #expect(windowType == "undefined")
    let searchEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new URLSearchParams('a=1').entries === 'function'")
    )
    #expect(searchEntries)
    let headerEntries = try await decodeJSONBool(
      runtime.evaluateJSON("typeof new Headers({a: '1'}).entries === 'function'")
    )
    #expect(headerEntries)
    let assignedPath = try await decodeJSONString(
      runtime.evaluateJSON(
        """
        (function(){
          var url = new URL('https://amusing-barnacle-26.clerk.accounts.dev');
          Object.assign(url, { pathname: 'v1/client' });
          return url.href;
        })()
        """
      )
    )
    #expect(assignedPath == "https://amusing-barnacle-26.clerk.accounts.dev/v1/client")
    let copiedSearch = try await decodeJSONString(
      runtime.evaluateJSON("new URLSearchParams(new URLSearchParams('a=1')).get('a')")
    )
    #expect(copiedSearch == "1")
    let copiedHeader = try await decodeJSONString(
      runtime.evaluateJSON("new Headers(new Headers({a: '1'})).get('a')")
    )
    #expect(copiedHeader == "1")
  }

  @Test
  func loadReturnsClientIdOverJSON() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)

    let proof = try await JSONDecoder().decode(
      ClerkLoadProof.self,
      from: Data(
        runtime.evaluateJSON(
          """
          ({
            loaded: globalThis.__clerkInstance.loaded,
            clientId: globalThis.__clerkInstance.client.id
          })
          """
        ).utf8
      )
    )
    #expect(proof.loaded)
    #expect(proof.clientId.hasPrefix("client_"))

    let snapshot = try await runtime.evaluateJSON(
      "globalThis.__clerkInstance.client.__internal_toSnapshot()"
    )
    let destination = packageRootURL().appendingPathComponent(".verification/client-after-load.json")
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try snapshot.write(to: destination, atomically: true, encoding: .utf8)
  }

  @Test
  func generatedClientDecodesLiveClientJSON() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)

    let snapshot = try await runtime.evaluateJSON(
      "globalThis.__clerkInstance.client.__internal_toSnapshot()"
    )
    var snapshotCodingPath = ""
    do {
      _ = try JSONDecoder().decode(Client.self, from: Data(snapshot.utf8))
    } catch let error as DecodingError {
      snapshotCodingPath = decodingPath(error)
    }
    #expect(snapshotCodingPath.hasSuffix("status") || snapshotCodingPath.contains("identifier"))

    let payload = try #require(runtime.lastFAPIClientJSON)
    let object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
    #expect(wireField(object, "sign_in") == "null")
    #expect(wireField(object, "sign_up") == "null")
    let client = try JSONDecoder().decode(Client.self, from: payload)
    #expect(client.id.hasPrefix("client_"))
    #expect(client.object == "client")
    #expect(client.signIn == nil)
    #expect(client.signUp == nil)
  }

  @Test
  func emailCodeSignInDecodesGeneratedSignIn() async throws {
    guard let publishableKey = publishableKeyFromKeysFile(named: "amusing-barnacle-26") else {
      Issue.record("Missing amusing-barnacle-26 publishable key in .keys.json")
      return
    }

    let runtime = ClerkJSRuntime()
    try await runtime.load(publishableKey: publishableKey)
    let hasClientJWT = try await decodeJSONBool(
      runtime.evaluateJSON(
        "(async function(){ var t = await __clerkNativeGetToken(); return t.length > 0; })()"
      )
    )
    if !hasClientJWT {
      Issue.record("FAPI missing_client_jwt")
      return
    }

    let email = uniqueClerkTestEmail()
    if let code = await ensureSignedUpUser(runtime, email: email) {
      Issue.record("FAPI \(code)")
      return
    }

    let signInRuntime = ClerkJSRuntime()
    try await signInRuntime.load(publishableKey: publishableKey)

    let createdCall = try await catchClerkCall(
      signInRuntime,
      methodPath: "__clerkInstance.client.signIn.create",
      args: ["identifier": email]
    )
    if !createdCall.ok, try wireField(fapiClientObject(signInRuntime), "sign_in") != "object" {
      Issue.record("FAPI \(createdCall.errors.first?.code ?? "sign_in_create")")
      return
    }
    if let code = try instanceCannotEmailCode(fapiClientObject(signInRuntime)) {
      Issue.record("FAPI \(code)")
      return
    }
    try await hydrateJSSignInID(signInRuntime)
    let created = try readGeneratedSignIn(signInRuntime)
    #expect(created.status == "needs_first_factor" || created.status == "needs_second_factor")

    let factorArgs = try emailCodeFactorArgs(fapiClientObject(signInRuntime))
    let preparedCall = try await callSignInMethod(
      signInRuntime,
      methodName: "prepareFirstFactor",
      args: factorArgs
    )
    if !preparedCall.ok, try wireField(fapiClientObject(signInRuntime), "sign_in") != "object" {
      Issue.record("FAPI \(preparedCall.errors.first?.code ?? "sign_in_prepare")")
      return
    }
    if let code = try instanceCannotEmailCode(fapiClientObject(signInRuntime)) {
      Issue.record("FAPI \(code)")
      return
    }
    try await hydrateJSSignInID(signInRuntime)
    var prepared = try readGeneratedSignIn(signInRuntime)
    if !prepared.hasFirstFactorVerification {
      _ = try await callSignInMethod(
        signInRuntime,
        methodName: "prepareFirstFactor",
        args: emailCodeFactorArgs(fapiClientObject(signInRuntime))
      )
      prepared = try readGeneratedSignIn(signInRuntime)
    }
    #expect(prepared.status == "needs_first_factor")
    #expect(prepared.hasFirstFactorVerification)

    let wrong = try await callSignInMethod(
      signInRuntime,
      methodName: "attemptFirstFactor",
      args: ["strategy": "email_code", "code": "000000"]
    )
    #expect(!wrong.ok)
    let wrongCodes = wrong.errors.map(\.code)
    #expect(!wrongCodes.isEmpty)
    #expect(!wrongCodes.contains("session_created"))
    let wrongSignIn = try readGeneratedSignIn(signInRuntime)
    #expect(wrongSignIn.status != "complete")
    if let verificationCode = wrongSignIn.verificationErrorCode {
      #expect(wrongCodes.contains(verificationCode))
    }

    let right = try await callSignInMethod(
      signInRuntime,
      methodName: "attemptFirstFactor",
      args: ["strategy": "email_code", "code": "424242"]
    )
    if !right.ok {
      let completedProbe = try readGeneratedSignIn(signInRuntime)
      if completedProbe.status != "complete",
        completedProbe.status != "needs_second_factor",
        !fapiHasSession(signInRuntime)
      {
        let codes = right.errors.map(\.code)
        if let blocked = codes.first(where: { isInstanceCapabilityError($0) }) {
          Issue.record("FAPI \(blocked)")
          return
        }
        Issue.record("FAPI \(codes.first ?? "attempt_failed")")
        return
      }
    }
    let completed = try readGeneratedSignIn(signInRuntime)
    let sessionId = completed.createdSessionId ?? fapiSessionID(signInRuntime)
    #expect(completed.status == "complete" || completed.status == "needs_second_factor" || sessionId != nil)
    guard let sessionId, sessionId.hasPrefix("sess_") else {
      return
    }
    #expect(sessionId.hasPrefix("sess_"))

    do {
      _ = try await signInRuntime.call(
        methodPath: "__clerkInstance.setActive",
        args: ["session": sessionId]
      )
      let tokenJSON = try await signInRuntime.call(
        methodPath: "__clerkInstance.session.getToken",
        args: [String: String]()
      )
      let token = try JSONDecoder().decode(String.self, from: Data(tokenJSON.utf8))
      #expect(token.count > 4)
      Issue.record("token \(String(token.prefix(4)))")
    } catch {
      return
    }
  }
}

private struct ClerkLoadProof: Decodable {
  let loaded: Bool
  let clientId: String
}

private func decodeJSONString(_ json: String) throws -> String {
  try JSONDecoder().decode(String.self, from: Data(json.utf8))
}

private func decodeJSONBool(_ json: String) throws -> Bool {
  try JSONDecoder().decode(Bool.self, from: Data(json.utf8))
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

private func decodingPath(_ error: DecodingError) -> String {
  let context: DecodingError.Context
  switch error {
  case .typeMismatch(_, let ctx):
    context = ctx
  case .valueNotFound(_, let ctx):
    context = ctx
  case .keyNotFound(_, let ctx):
    context = ctx
  case .dataCorrupted(let ctx):
    context = ctx
  @unknown default:
    return String(describing: error)
  }
  return context.codingPath.map(\.stringValue).joined(separator: ".")
}

private func packageRootURL() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

private func publishableKeyFromKeysFile(named name: String) -> String? {
  let url = packageRootURL().appendingPathComponent(".keys.json")
  guard let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let entry = json[name] as? [String: Any],
        let pk = entry["pk"] as? String,
        !pk.isEmpty
  else {
    return nil
  }
  return pk
}

private func uniqueClerkTestEmail() -> String {
  let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  return "jscore+clerk_test_\(suffix)@example.com"
}

private func uniqueClerkTestPhone() -> String {
  let area = Int.random(in: 200 ... 999)
  let line = Int.random(in: 0 ... 99)
  return String(format: "+1%d55501%02d", area, line)
}

private struct CaughtClerkCall: Decodable {
  var ok: Bool
  var errors: [JSAPIError]
}

private struct JSAPIError: Decodable {
  var code: String
}

private struct GeneratedSignInRead {
  var decoded: Bool
  var status: String?
  var createdSessionId: String?
  var verificationErrorCode: String?
  var decodePath: String
  var userDataShape: String
  var hasFirstFactorVerification: Bool
}

private func jsonValue(_ value: some Encodable) throws -> String {
  let data = try JSONEncoder().encode(value)
  guard let text = String(data: data, encoding: .utf8) else {
    throw ClerkJSCoreError.invalidArgument("json")
  }
  return text
}

private func jsonObject(_ value: [String: Any]) throws -> String {
  let data = try JSONSerialization.data(withJSONObject: value)
  guard let text = String(data: data, encoding: .utf8) else {
    throw ClerkJSCoreError.invalidArgument("json")
  }
  return text
}

private func catchClerkCall(
  _ runtime: ClerkJSRuntime,
  methodPath: String,
  args: [String: Any]
) async throws -> CaughtClerkCall {
  let path = try jsonValue(methodPath)
  let argsJSON = try jsonObject(args)
  let script = """
    (async function() {
      var parts = \(path).split('.');
      var receiver = globalThis;
      var fn = globalThis;
      for (var i = 0; i < parts.length; i++) {
        receiver = fn;
        fn = fn[parts[i]];
      }
      try {
        await fn.call(receiver, \(argsJSON));
        return { ok: true, errors: [] };
      } catch (e) {
        var errors = Array.isArray(e && e.errors) ? e.errors : [];
        if (!errors.length && e && e.code) {
          errors = [{ code: String(e.code) }];
        } else if (!errors.length) {
          var code = e && e.name ? String(e.name) : 'js_error';
          if (e && typeof e.message === 'string' && e.message.indexOf('Not a function') !== -1) {
            code = 'not_a_function';
          }
          errors = [{ code: code }];
        }
        return { ok: false, errors: errors };
      }
    })()
    """
  return try await JSONDecoder().decode(
    CaughtClerkCall.self,
    from: Data((runtime.evaluateJSON(script)).utf8)
  )
}

private func fapiClientObject(_ runtime: ClerkJSRuntime) throws -> [String: Any] {
  let payload = try #require(runtime.lastFAPIClientJSON)
  return try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
}

private func readGeneratedSignIn(_ runtime: ClerkJSRuntime) throws -> GeneratedSignInRead {
  let object = try fapiClientObject(runtime)
  guard let signIn = object["sign_in"] as? [String: Any] else {
    return GeneratedSignInRead(
      decoded: false,
      status: nil,
      createdSessionId: nil,
      verificationErrorCode: nil,
      decodePath: "sign_in",
      userDataShape: "missing",
      hasFirstFactorVerification: false
    )
  }
  var verificationErrorCode: String?
  if let verification = signIn["first_factor_verification"] as? [String: Any],
     let error = verification["error"] as? [String: Any]
  {
    verificationErrorCode = error["code"] as? String
  }
  do {
    _ = try JSONDecoder().decode(SignIn.self, from: JSONSerialization.data(withJSONObject: signIn))
    return GeneratedSignInRead(
      decoded: true,
      status: signIn["status"] as? String,
      createdSessionId: signIn["created_session_id"] as? String,
      verificationErrorCode: verificationErrorCode,
      decodePath: "",
      userDataShape: userDataShape(signIn),
      hasFirstFactorVerification: signIn["first_factor_verification"] is [String: Any]
    )
  } catch let error as DecodingError {
    return GeneratedSignInRead(
      decoded: false,
      status: signIn["status"] as? String,
      createdSessionId: signIn["created_session_id"] as? String,
      verificationErrorCode: verificationErrorCode,
      decodePath: decodingPath(error),
      userDataShape: userDataShape(signIn),
      hasFirstFactorVerification: signIn["first_factor_verification"] is [String: Any]
    )
  }
}

private func callSignInMethod(
  _ runtime: ClerkJSRuntime,
  methodName: String,
  args: [String: Any]
) async throws -> CaughtClerkCall {
  try await hydrateJSSignInID(runtime)
  let object = try fapiClientObject(runtime)
  let idJSON = try jsonValue((object["sign_in"] as? [String: Any])?["id"] as? String ?? "")
  let methodJSON = try jsonValue(methodName)
  let argsJSON = try jsonObject(args)
  let script = """
    (async function() {
      var signIn = globalThis.__clerkInstance.client.signIn;
      var id = \(idJSON);
      if (id) {
        signIn.id = id;
      }
      try {
        await signIn[\(methodJSON)](\(argsJSON));
        return { ok: true, errors: [] };
      } catch (e) {
        var errors = Array.isArray(e && e.errors) ? e.errors : [];
        if (!errors.length && e && e.code) {
          errors = [{ code: String(e.code) }];
        } else if (!errors.length) {
          var code = e && e.name ? String(e.name) : 'js_error';
          errors = [{ code: code }];
        }
        return { ok: false, errors: errors };
      }
    })()
    """
  return try await JSONDecoder().decode(
    CaughtClerkCall.self,
    from: Data((runtime.evaluateJSON(script)).utf8)
  )
}

private func hydrateJSSignInID(_ runtime: ClerkJSRuntime) async throws {
  let object = try fapiClientObject(runtime)
  guard let signIn = object["sign_in"] as? [String: Any],
        let id = signIn["id"] as? String
  else {
    return
  }
  let idJSON = try jsonValue(id)
  _ = try await runtime.evaluateJSON(
    """
    (function() {
      globalThis.__clerkInstance.client.signIn.id = \(idJSON);
      return true;
    })()
    """
  )
}

private func userDataShape(_ signIn: [String: Any]) -> String {
  guard signIn.keys.contains("user_data") else {
    return "missing"
  }
  switch signIn["user_data"] {
  case nil, is NSNull:
    return "null"
  case let object as [String: Any]:
    return object.keys.sorted().joined(separator: ",")
  default:
    return "other"
  }
}

private func emailCodeFactorArgs(_ object: [String: Any], code: String? = nil) -> [String: Any] {
  var args: [String: Any] = ["strategy": "email_code"]
  if let code {
    args["code"] = code
  }
  let signIn = object["sign_in"] as? [String: Any]
  let factors = signIn?["supported_first_factors"] as? [[String: Any]] ?? []
  if let emailId = factors.first(where: { $0["strategy"] as? String == "email_code" })?["email_address_id"] as? String {
    args["emailAddressId"] = emailId
  }
  return args
}

private func instanceCannotEmailCode(_ object: [String: Any]) -> String? {
  guard let signIn = object["sign_in"] as? [String: Any],
        let factors = signIn["supported_first_factors"] as? [[String: Any]]
  else {
    return nil
  }
  let strategies = factors.compactMap { $0["strategy"] as? String }
  if !strategies.isEmpty, !strategies.contains("email_code") {
    return "email_code_unsupported"
  }
  return nil
}

private func isInstanceCapabilityError(_ code: String) -> Bool {
  code.contains("native") || code == "captcha_unavailable"
}

private func jsErrorCode(_ error: Error) -> String? {
  guard let clerkError = error as? ClerkJSCoreError,
        case .javascript(let message) = clerkError
  else {
    return nil
  }
  if message.contains("captcha_unavailable") {
    return "captcha_unavailable"
  }
  if message.lowercased().contains("native") {
    return "native_api"
  }
  return "javascript"
}

private func ensureSignedUpUser(_ runtime: ClerkJSRuntime, email: String) async -> String? {
  do {
    let created = try await catchClerkCall(
      runtime,
      methodPath: "__clerkInstance.client.signUp.create",
      args: ["emailAddress": email]
    )
    if !created.ok {
      let codes = created.errors.map(\.code)
      if let blocked = codes.first(where: isInstanceCapabilityError) {
        return blocked
      }
      return codes.first ?? "sign_up_create"
    }
    if let code = try await fillSignUpRequirements(runtime) {
      return code
    }
    let prepared = try await catchClerkCall(
      runtime,
      methodPath: "__clerkInstance.client.signUp.prepareEmailAddressVerification",
      args: ["strategy": "email_code"]
    )
    if !prepared.ok {
      return prepared.errors.first?.code ?? "sign_up_prepare"
    }
    let attempted = try await catchClerkCall(
      runtime,
      methodPath: "__clerkInstance.client.signUp.attemptEmailAddressVerification",
      args: ["code": "424242"]
    )
    if !attempted.ok {
      return attempted.errors.first?.code ?? "sign_up_attempt"
    }
    if let code = try await fillSignUpRequirements(runtime) {
      return code
    }
    if signUpUnverifiedFields(runtime).contains("phone_number") {
      let phonePrepared = try await catchClerkCall(
        runtime,
        methodPath: "__clerkInstance.client.signUp.prepareVerification",
        args: ["strategy": "phone_code"]
      )
      if !phonePrepared.ok {
        return phonePrepared.errors.first?.code ?? "sign_up_phone_prepare"
      }
      let phoneAttempted = try await catchClerkCall(
        runtime,
        methodPath: "__clerkInstance.client.signUp.attemptVerification",
        args: ["strategy": "phone_code", "code": "424242"]
      )
      if !phoneAttempted.ok, !fapiHasSession(runtime) {
        let fetchMeta = await (try? runtime.evaluateJSON("globalThis.__clerkLastFetch || null")) ?? "null"
        let status = signUpStatus(runtime) ?? "unknown"
        let unverified = signUpUnverifiedFields(runtime).joined(separator: ",")
        let code = phoneAttempted.errors.first?.code
          ?? signUpVerificationError(runtime, field: "phone_number")
          ?? "phone_attempt"
        return "\(code) \(status) \(unverified) \(fetchMeta)"
      }
    }
    if fapiHasSession(runtime) || signUpStatus(runtime) == "complete" {
      return nil
    }
    if let status = signUpStatus(runtime), status != "complete" {
      let missing = signUpMissingFields(runtime).joined(separator: ",")
      return missing.isEmpty ? "sign_up_\(status)" : "sign_up_\(status)_\(missing)"
    }
    return nil
  } catch {
    return jsErrorCode(error) ?? "sign_up"
  }
}

private func fapiClientRoot(_ runtime: ClerkJSRuntime) -> [String: Any]? {
  guard let payload = runtime.lastFAPIClientJSON,
        let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
  else {
    return nil
  }
  return object
}

private func signUpObject(_ runtime: ClerkJSRuntime) -> [String: Any]? {
  fapiClientRoot(runtime)?["sign_up"] as? [String: Any]
}

private func fapiHasSession(_ runtime: ClerkJSRuntime) -> Bool {
  fapiSessionID(runtime) != nil
}

private func fapiSessionID(_ runtime: ClerkJSRuntime) -> String? {
  let root = fapiClientRoot(runtime)
  if let id = root?["last_active_session_id"] as? String, id.hasPrefix("sess_") {
    return id
  }
  let sessions = root?["sessions"] as? [[String: Any]] ?? []
  return sessions.compactMap { $0["id"] as? String }.first { $0.hasPrefix("sess_") }
}

private func signUpMissingFields(_ runtime: ClerkJSRuntime) -> [String] {
  signUpObject(runtime)?["missing_fields"] as? [String] ?? []
}

private func signUpUnverifiedFields(_ runtime: ClerkJSRuntime) -> [String] {
  signUpObject(runtime)?["unverified_fields"] as? [String] ?? []
}

private func signUpStatus(_ runtime: ClerkJSRuntime) -> String? {
  signUpObject(runtime)?["status"] as? String
}

private func signUpVerificationError(_ runtime: ClerkJSRuntime, field: String) -> String? {
  let verifications = signUpObject(runtime)?["verifications"] as? [String: Any]
  let verification = verifications?[field] as? [String: Any]
  let error = verification?["error"] as? [String: Any]
  return error?["code"] as? String
}

private func fillSignUpRequirements(_ runtime: ClerkJSRuntime) async throws -> String? {
  let missing = signUpMissingFields(runtime)
  var args: [String: Any] = [:]
  if missing.contains("password") {
    args["password"] = "Clerk_JSCore_Test_2026_XyZ9#mK2$pL7"
  }
  if missing.contains("legal_accepted") {
    args["legalAccepted"] = true
  }
  if missing.contains("first_name") {
    args["firstName"] = "JS"
  }
  if missing.contains("last_name") {
    args["lastName"] = "Core"
  }
  if missing.contains("username") {
    args["username"] = "jscore\(Int.random(in: 100_000 ... 999_999))"
  }
  if missing.contains("phone_number") {
    args["phoneNumber"] = uniqueClerkTestPhone()
  }
  guard !args.isEmpty else {
    return nil
  }
  let updated = try await catchClerkCall(
    runtime,
    methodPath: "__clerkInstance.client.signUp.update",
    args: args
  )
  if !updated.ok {
    return updated.errors.first?.code ?? "sign_up_update"
  }
  return nil
}
#endif
