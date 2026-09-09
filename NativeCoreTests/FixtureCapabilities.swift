import Foundation
#if SWIFT_PACKAGE
import ClerkKit
#endif

@MainActor final class FixtureCapabilities: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random", "browser"]
  let fixtures: [String: JSONValue]
  var credential: String?
  var requests: [[String: JSONValue]] = []
  var browserCount = 0
  var clientReads = 0
  var signedOut = false
  init(data: Data) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: data).object()
  }

  init(path: String) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: path))).object()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "storage.read" { return credential.map(JSONValue.string) ?? .null }
    if capability == "storage.write" { credential = try (args["value"] ?? .undefined).string(); return .null }
    if capability == "storage.remove" { credential = nil; return .null }
    if capability == "timer" { try await Task.sleep(for: .milliseconds((args["milliseconds"] ?? .number(0)).number())); return .null }
    if capability == "browser" {
      browserCount += 1
      precondition(args["url"] == .string("https://provider.example/authorize"))
      return .object(["callbackUrl": .string("clerk-test://sso-callback?rotating_token_nonce=native_nonce")])
    }
    guard capability == "http" else { throw CoreError(code: "unexpected_capability") }
    requests.append(args)
    let url = try (args["url"] ?? .undefined).url()
    var response: JSONValue
    if url.path.hasSuffix("/environment") { response = fixtures["environment"]! }
    else if url.path.hasSuffix("/client") {
      clientReads += 1
      response = fixtures[clientReads > 1 && !signedOut ? "authenticatedClient" : "client"]!
    } else if url.path.hasSuffix("/sessions") { signedOut = true; response = fixtures["client"]! }
    else if url.path.hasSuffix("/tokens") {
      return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(data: JSONEncoder().encode(fixtures["token"]!), encoding: .utf8)!)])
    } else if url.path.hasSuffix("/touch") {
      let payload = JSONValue.object(["response": fixtures["session"]!, "client": fixtures["authenticatedClient"]!])
      return try .object(["status": .number(200), "headers": .object([:]), "body": .string(String(data: JSONEncoder().encode(payload), encoding: .utf8)!)])
    } else {
      var resource = try fixtures[url.path.contains("sign_ins") ? "signIn" : "signUp"]!.object()
      if args["method"] == .string("GET") {
        precondition(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "rotating_token_nonce" && $0.value == "native_nonce" }) == true)
        resource["status"] = .string("complete")
        resource["created_session_id"] = .string("sess_native")
      }
      response = .object(resource)
    }
    let body = try String(data: JSONEncoder().encode(JSONValue.object(["response": response])), encoding: .utf8)!
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(body)])
  }
}
