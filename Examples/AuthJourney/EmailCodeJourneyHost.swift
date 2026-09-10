import ClerkKit
import Foundation
import Observation

@MainActor @Observable
final class EmailCodeJourneyHost: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random"]
  private let fixtures: [String: JSONValue]
  private let environment: JSONValue
  private let expires = Date().timeIntervalSince1970 * 1000 + 3_600_000
  private var credential = JSONValue.null
  private var signIn = JSONValue.null
  private var complete = false
  private(set) var touches = 0
  private(set) var attemptedCodes: [String] = []

  init(data: Data) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: data).object()
    var environment = try (fixtures["environment"] ?? .undefined).object()
    var settings = try (environment["user_settings"] ?? .undefined).object()
    var attributes = try (settings["attributes"] ?? .undefined).object()
    var email = try (attributes["email_address"] ?? .undefined).object()
    email["enabled"] = .bool(true)
    email["used_for_first_factor"] = .bool(true)
    email["first_factors"] = .array([.string("email_code")])
    email["verifications"] = .array([.string("email_code")])
    attributes["email_address"] = .object(email)
    settings["attributes"] = .object(attributes)
    environment["user_settings"] = .object(settings)
    self.environment = .object(environment)
  }

  private func session() throws -> JSONValue {
    var value = try (fixtures["session"] ?? .undefined).object()
    value["expire_at"] = .number(expires)
    value["abandon_at"] = .number(expires)
    return .object(value)
  }

  private func client() throws -> JSONValue {
    var value = try (fixtures["client"] ?? .undefined).object()
    value["sign_in"] = signIn
    value["sessions"] = try .array(complete ? [session()] : [])
    value["last_active_session_id"] = touches > 0 ? .string("sess_native") : .null
    return .object(value)
  }

  private func updateSignIn(prepared: Bool = false) throws {
    var value = try (fixtures["signIn"] ?? .undefined).object()
    value["identifier"] = .string("test@example.com")
    value["status"] = .string(complete ? "complete" : "needs_first_factor")
    value["created_session_id"] = complete ? .string("sess_native") : .null
    value["supported_first_factors"] = .array([.object([
      "strategy": .string("email_code"), "email_address_id": .string("idn_email"),
      "safe_identifier": .string("test@example.com"),
    ])])
    if prepared || complete {
      var verification = try (value["first_factor_verification"] ?? .undefined).object()
      verification["status"] = .string(complete ? "verified" : "unverified")
      verification["strategy"] = .string("email_code")
      verification["external_verification_redirect_url"] = .null
      verification["expire_at"] = .number(expires)
      value["first_factor_verification"] = .object(verification)
    } else {
      value["first_factor_verification"] = .null
    }
    signIn = .object(value)
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    switch capability {
    case "storage.read": return credential
    case "storage.write": credential = args["value"] ?? .null; return .null
    case "storage.remove": credential = .null; return .null
    case "timer":
      try await Task.sleep(for: .milliseconds((args["milliseconds"] ?? .number(0)).number()))
      return .null
    default: break
    }
    guard capability == "http" else { throw CoreError(code: "unexpected_journey_capability", message: capability) }
    let path = try (args["url"] ?? .undefined).url().path
    let encodedBody = (try? args["body"]?.string()) ?? ""
    let form = URLComponents(string: "https://fixture/?" + encodedBody)?.queryItems ?? []
    func field(_ name: String) -> String? {
      form.first { $0.name == name }?.value
    }
    func require(_ condition: Bool) throws {
      guard condition else { throw CoreError(code: "unexpected_journey_request", message: path) }
    }
    var status = 200
    let body: JSONValue
    if path.hasSuffix("/environment") {
      body = .object(["response": environment])
    } else if path.hasSuffix("/client") {
      body = try .object(["response": client()])
    } else if path.hasSuffix("/client/sign_ins") {
      try require(field("identifier") == "test@example.com")
      try updateSignIn()
      body = try .object(["response": signIn, "client": client()])
    } else if path.hasSuffix("/prepare_first_factor") {
      try require(field("strategy") == "email_code")
      try updateSignIn(prepared: true)
      body = try .object(["response": signIn, "client": client()])
    } else if path.hasSuffix("/attempt_first_factor") {
      try require(field("strategy") == "email_code")
      guard let code = field("code") else { throw CoreError.invalidValue }
      attemptedCodes.append(code)
      if code == "424242" {
        complete = true
        try updateSignIn()
        body = try .object(["response": signIn, "client": client()])
      } else {
        status = 422
        body = .object(["errors": .array([.object([
          "code": .string("form_code_incorrect"), "message": .string("Incorrect code"),
          "long_message": .string("That code is incorrect. Try again."),
        ])])])
      }
    } else if path.hasSuffix("/touch") {
      try require(complete)
      touches += 1
      body = try .object(["response": session(), "client": client()])
    } else if path.hasSuffix("/tokens") {
      func encode(_ value: JSONValue) throws -> String {
        try JSONEncoder().encode(value).base64EncodedString()
          .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
          .replacingOccurrences(of: "=", with: "")
      }
      let header = try encode(.object(["alg": .string("RS256"), "typ": .string("JWT")]))
      let payload = try encode(.object([
        "sub": .string("user_native"), "sid": .string("sess_native"),
        "iat": .number(floor(Date().timeIntervalSince1970)), "exp": .number(floor(expires / 1000)),
      ]))
      body = .object(["object": .string("token"), "jwt": .string("\(header).\(payload).fixture_signature")])
    } else {
      throw CoreError(code: "unexpected_journey_path", message: path)
    }
    return try .object([
      "status": .number(Double(status)),
      "headers": .object(path.hasSuffix("/environment") ? [:] : ["authorization": .string("fixture-credential")]),
      "body": .string(String(decoding: JSONEncoder().encode(body), as: UTF8.self)),
    ])
  }
}
