import CryptoKit
import Foundation
#if SWIFT_PACKAGE
import ClerkKit
#endif

@MainActor final class FixtureCapabilities: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random", "browser", "appleIdentity", "passkeys", "authStorage", "crypto.sha256"]
  let fixtures: [String: JSONValue]
  var authRecord: String?
  var credential: String?
  var requests: [[String: JSONValue]] = []
  var browserCount = 0
  var appleIdentityCount = 0
  var clientReads = 0
  var signedOut = false
  var nextAuthError: JSONValue?
  init(data: Data) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: data).object()
  }

  init(path: String) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: path))).object()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "authStorage.read" { return authRecord.map(JSONValue.string) ?? .null }
    if capability == "authStorage.write" { authRecord = try (args["value"] ?? .undefined).string(); return .null }
    if capability == "authStorage.remove" { authRecord = nil; return .null }
    if capability == "crypto.sha256" {
      return try .string(Data(SHA256.hash(data: Data((args["value"] ?? .undefined).string().utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: ""))
    }
    if capability == "storage.read" { return credential.map(JSONValue.string) ?? .null }
    if capability == "storage.write" { credential = try (args["value"] ?? .undefined).string(); return .null }
    if capability == "storage.remove" { credential = nil; return .null }
    if capability == "timer" { try await Task.sleep(for: .milliseconds((args["milliseconds"] ?? .number(0)).number())); return .null }
    if capability == "appleIdentity" {
      appleIdentityCount += 1
      return .object(["token": .string("apple-fixture-token"), "firstName": .string("Apple"), "lastName": .string("User")])
    }
    if capability == "browser" {
      browserCount += 1
      precondition(args["url"] == .string("https://provider.example/authorize"))
      return .object(["callbackUrl": .string("clerk-test://sso-callback?rotating_token_nonce=native_nonce")])
    }
    guard capability == "http" else { throw CoreError(code: "unexpected_capability") }
    requests.append(args)
    let url = try (args["url"] ?? .undefined).url()
    if url.path.contains("sign_ins"), let error = nextAuthError {
      nextAuthError = nil
      let body = try String(data: JSONEncoder().encode(error), encoding: .utf8)!
      return .object(["status": .number(422), "headers": .object([:]), "body": .string(body)])
    }
    var response: JSONValue
    if url.path.hasSuffix("/magic_links/complete") {
      var signUp = try fixtures["signUp"]!.object()
      signUp["status"] = .string("complete")
      signUp["created_session_id"] = .string("sess_native")
      response = .object(signUp)
    } else if url.path.hasSuffix("/environment") { response = fixtures["environment"]! }
    else if url.path.hasSuffix("/client") {
      clientReads += 1
      response = fixtures[clientReads > 1 && !signedOut ? "authenticatedClient" : "client"]!
    } else if url.path.hasSuffix("/sessions") { signedOut = true; response = fixtures["client"]! }
    else if url.path.hasSuffix("/tokens") {
      return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(data: JSONEncoder().encode(fixtures["token"]!), encoding: .utf8)!)])
    } else if url.path.hasSuffix("/touch") {
      let payload = JSONValue.object(["response": fixtures["session"]!, "client": fixtures["authenticatedClient"]!])
      return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(data: JSONEncoder().encode(payload), encoding: .utf8)!)])
    } else if url.path.contains("/phone_numbers") {
      let verification = JSONValue.object(["status": .string("verified"), "strategy": .string("phone_code"), "attempts": .null, "expire_at": .null, "error": .null, "verified_at_client": .null])
      var phone: [String: JSONValue] = ["object": .string("phone_number"), "id": .string("phone_native"), "phone_number": .string("+15555550123"), "verification": verification, "reserved_for_second_factor": .bool(false), "default_second_factor": .bool(false), "linked_to": .array([])]
      if url.path.hasSuffix("phone_native") {
        phone["reserved_for_second_factor"] = .bool(true)
        phone["backup_codes"] = .array([.string("fixture-recovery-code")])
      }
      response = .object(phone)
    } else {
      var resource = try fixtures[url.path.contains("sign_ins") ? "signIn" : "signUp"]!.object()
      if args["method"] == .string("GET") {
        precondition(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "rotating_token_nonce" && $0.value == "native_nonce" }) == true)
        resource["status"] = .string("complete")
        resource["created_session_id"] = .string("sess_native")
      }
      if case .string(let body) = args["body"], body.contains("oauth_token_apple") {
        precondition(body.contains("apple-fixture-token"))
        resource["status"] = .string("complete")
        resource["created_session_id"] = .string("sess_native")
      }
      response = .object(resource)
    }
    let body = try String(data: JSONEncoder().encode(JSONValue.object(["response": response])), encoding: .utf8)!
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(body)])
  }
}
