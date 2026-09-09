import ClerkKit
import Foundation
@testable import NativeCoreProof
import Testing

extension PackagedCoreTests {
  @Test func generatedSessionVerificationReturnsUsableFactorState() async throws {
    let host = try SessionVerificationCapabilities()
    let key = "pk_test_" + Data("native-core.clerk.accounts.dev$".utf8).base64EncodedString()
    let clerk = try await Clerk.connect(configuration: .init(publishableKey: key, callbackURL: #require(URL(string: "clerk-test://sso-callback"))), capabilities: host)
    defer { clerk.close() }
    let session = try #require(clerk.session)
    func verify(_ result: SessionVerification, status: SessionVerificationStatus, path: String, body: [String: String]) throws {
      #expect(result.status == status)
      #expect(result.level == .multiFactor)
      #expect(result.session.id == session.id)
      #expect(result.firstFactorVerification.status == .unverified)
      #expect(result.secondFactorVerification.status == nil)
      guard case .case5(let enterprise) = try #require(result.supportedFirstFactors?.first),
            case .case1(let phone) = try #require(result.supportedSecondFactors?.first)
      else {
        Issue.record("Expected enterprise and phone metadata"); return
      }
      #expect(enterprise.enterpriseConnectionId == "econn_123")
      #expect(enterprise.enterpriseConnectionName == "Acme")
      #expect(phone.phoneNumberId == "idn_phone" && phone.safeIdentifier == "+15555550123")
      #expect(phone.primary == true && phone.default == true)
      #expect(host.paths.last == "/v1/client/sessions/sess_native/" + path)
      #expect(host.bodies.last == body)
    }
    for level: SessionVerificationLevel in [.firstFactor, .secondFactor, .multiFactor] {
      try await verify(session.startVerification(.init(level: level)), status: .needsFirstFactor, path: "verify", body: ["level": level.rawValue])
    }
    let first: [(SessionVerifyPrepareFirstFactorParams, [String: String])] = [
      (.case1(.init()), ["strategy": "passkey"]),
      (.case2(.init(emailAddressId: "idn_email")), ["strategy": "email_code", "email_address_id": "idn_email"]),
      (.case3(.init(phoneNumberId: "idn_phone", default: true)), ["strategy": "phone_code", "phone_number_id": "idn_phone", "default": "true"]),
      (.case4(.init(emailAddressId: "idn_email", enterpriseConnectionId: "econn_123", redirectUrl: "clerk-test://sso-callback")), ["strategy": "enterprise_sso", "email_address_id": "idn_email", "enterprise_connection_id": "econn_123", "redirect_url": "clerk-test://sso-callback"]),
    ]
    for (params, body) in first {
      try await verify(session.prepareFirstFactorVerification(params), status: .needsFirstFactor, path: "verify/prepare_first_factor", body: body)
    }
    let attempts: [(SessionVerifyAttemptFirstFactorParams, [String: String])] = [
      (.case1(.init(code: "123456")), ["strategy": "email_code", "code": "123456"]),
      (.case2(.init(code: "123456")), ["strategy": "phone_code", "code": "123456"]),
      (.case3(.init(password: "fixture-password")), ["strategy": "password", "password": "fixture-password"]),
    ]
    for (params, body) in attempts {
      try await verify(session.attemptFirstFactorVerification(params), status: .complete, path: "verify/attempt_first_factor", body: body)
    }
    try await verify(session.prepareSecondFactorVerification(.init(phoneNumberId: "idn_phone")), status: .needsSecondFactor, path: "verify/prepare_second_factor", body: ["strategy": "phone_code", "phone_number_id": "idn_phone"])
    let second: [SessionVerifyAttemptSecondFactorParams] = [.case1(.init(code: "123456")), .case2(.init(code: "123456")), .case3(.init(code: "123456"))]
    for params in second {
      try await verify(session.attemptSecondFactorVerification(params), status: .complete, path: "verify/attempt_second_factor", body: ["strategy": params.strategy, "code": "123456"])
    }
    host.failNext = true
    do { _ = try await session.attemptFirstFactorVerification(.case1(.init(code: "123456"))); Issue.record("Expected invalid code") }
    catch let error as CoreError { #expect(error.status == 422 && error.errors.first?.code == "form_code_incorrect") }
    #expect(try await session.attemptFirstFactorVerification(.case1(.init(code: "123456"))).status == .complete)
    #expect(clerk.session?.id == session.id)
    #expect(host.paths.count == 16)
  }
}

@MainActor private final class SessionVerificationCapabilities: NativeCapabilities {
  let base: FixtureCapabilities
  var supported: [String] {
    base.supported
  }

  var paths: [String] = []
  var bodies: [[String: String]] = []
  var failNext = false
  init() throws {
    base = try FixtureCapabilities(data: PackageProof.fixtureData())
    base.clientResponse = base.fixtures["authenticatedClient"]
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    guard capability == "http" else { return try await base.perform(capability, arguments: arguments) }
    let args = try arguments.object()
    let path = try args["url"]!.url().path
    guard path.contains("/verify") else { return try await base.perform(capability, arguments: arguments) }
    #expect(args["method"] == .string("POST"))
    paths.append(path)
    var components = URLComponents()
    components.percentEncodedQuery = try args["body"]!.string()
    bodies.append(Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }))
    if failNext {
      failNext = false
      return .object(["status": .number(422), "headers": .object([:]), "body": .string("{\"errors\":[{\"code\":\"form_code_incorrect\",\"message\":\"Incorrect code\"}]}")])
    }
    let raw = """
    {"object":"session_verification","id":"sv_fixture","status":"needs_first_factor","level":"multi_factor","first_factor_verification":{"status":"unverified","strategy":"enterprise_sso","attempts":0,"expire_at":null,"error":null,"verified_at_client":null},"second_factor_verification":null,"supported_first_factors":[{"strategy":"enterprise_sso","enterprise_connection_id":"econn_123","enterprise_connection_name":"Acme"}],"supported_second_factors":[{"strategy":"phone_code","phone_number_id":"idn_phone","safe_identifier":"+15555550123","primary":true,"default":true}]}
    """
    var verification = try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8)).object()
    verification["session"] = try base.fixtures["authenticatedClient"]!.object()["sessions"]!.array()[0]
    verification["status"] = .string(path.contains("attempt") ? "complete" : path.contains("second") ? "needs_second_factor" : "needs_first_factor")
    let body = JSONValue.object(["response": .object(verification)])
    return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self))])
  }
}
