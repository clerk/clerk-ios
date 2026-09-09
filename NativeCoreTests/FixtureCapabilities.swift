import CryptoKit
import Foundation
#if SWIFT_PACKAGE
import ClerkKit
#endif

@MainActor final class FixtureCapabilities: NativeCapabilities {
  let supported = ["http", "storage", "timer", "random", "browser", "appleIdentity", "passkeys", "authStorage", "crypto.sha256", "biometrics"]
  let fixtures: [String: JSONValue]
  var biometricRecords: String?
  var biometricCleanup: String?
  var biometricSignCount = 0
  var authRecord: String?
  var credential: String?
  var requests: [[String: JSONValue]] = []
  var browserCount = 0
  var appleIdentityCount = 0
  var clientReads = 0
  var signedOut = false
  var clientResponse: JSONValue?
  var sessionReloadResponse: JSONValue?
  var signInFirstFactors: JSONValue?
  var nextAuthError: JSONValue?
  var nextAuthErrorStatus = 422
  var nextAuthErrorHeaders: [String: JSONValue] = [:]
  init(data: Data) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: data).object()
  }

  init(path: String) throws {
    fixtures = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: URL(fileURLWithPath: path))).object()
  }

  func perform(_ capability: String, arguments: JSONValue) async throws -> JSONValue {
    let args = try arguments.object()
    if capability == "biometrics.appIdentifier" { return .string("com.example.native") }
    if capability == "biometrics.storage.read" { return (args["key"] == .string("credentials") ? biometricRecords : biometricCleanup).map(JSONValue.string) ?? .null }
    if capability == "biometrics.storage.write" {
      if args["key"] == .string("credentials") { biometricRecords = try (args["value"] ?? .undefined).string() }
      else { biometricCleanup = try (args["value"] ?? .undefined).string() }
      return .null
    }
    if capability == "biometrics.supports" || capability == "biometrics.hasKey" { return .bool(true) }
    if capability == "biometrics.deleteKey" { return .null }
    if capability == "biometrics.createKey" { return .object(["localKeyId": .string("tdlk_native"), "publicKeyJwk": .string("{\"kty\":\"EC\"}")]) }
    if capability == "biometrics.sign" {
      biometricSignCount += 1
      precondition(args["clientData"] == .string("native_fixture_client_data"))
      return .object(["clientData": .string("native_fixture_client_data"), "signature": .string("native_fixture_signature"), "algorithm": .string("ES256")])
    }
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
      return .object(["status": .number(Double(nextAuthErrorStatus)), "headers": .object(nextAuthErrorHeaders), "body": .string(body)])
    }
    if url.path.hasSuffix("/sessions/sess_native"), let sessionReloadResponse {
      let body = try String(data: JSONEncoder().encode(sessionReloadResponse), encoding: .utf8)!
      return .object(["status": .number(200), "headers": .object([:]), "body": .string(body)])
    }
    var response: JSONValue
    if url.path.hasSuffix("/magic_links/complete") {
      var signUp = try fixtures["signUp"]!.object()
      signUp["status"] = .string("complete")
      signUp["created_session_id"] = .string("sess_native")
      response = .object(signUp)
    } else if url.path.hasSuffix("/environment") {
      var environment = try fixtures["environment"]!.object()
      var auth = try environment["auth_config"]!.object()
      auth["native_settings"] = .object(["api_enabled": .bool(true), "trusted_device_sign_in_enabled": .bool(true)])
      environment["auth_config"] = .object(auth)
      response = .object(environment)
    } else if url.path.hasSuffix("/biometric_credentials/prepare") { response = biometricChallenge }
    else if url.path.hasSuffix("/biometric_credentials/attempt") {
      response = .object(["id": .string("td_native"), "object": .string("trusted_device"), "platform": .string("ios"), "app_identifier": .string("com.example.native"), "name": .null, "algorithm": .string("ES256"), "status": .string("active"), "created_at": .number(Date().timeIntervalSince1970 * 1000), "updated_at": .number(Date().timeIntervalSince1970 * 1000), "last_used_at": .null, "revoked_at": .null])
    } else if url.path.hasSuffix("/client") {
      clientReads += 1
      response = clientResponse ?? fixtures[clientReads > 1 && !signedOut ? "authenticatedClient" : "client"]!
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
      if url.path.contains("sign_ins"), let signInFirstFactors { resource["supported_first_factors"] = signInFirstFactors }
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
      if case .string(let body) = args["body"], body.contains("trusted_device") {
        if url.path.hasSuffix("/attempt_first_factor") {
          precondition(body.contains("native_fixture_signature"))
          resource["status"] = .string("complete")
          resource["created_session_id"] = .string("sess_native")
        } else {
          var verification = try resource["first_factor_verification"]!.object()
          verification["trusted_device_challenge"] = biometricChallenge
          resource["first_factor_verification"] = .object(verification)
        }
      }
      response = .object(resource)
    }
    let body = try String(data: JSONEncoder().encode(JSONValue.object(["response": response])), encoding: .utf8)!
    return .object(["status": .number(200), "headers": .object(["authorization": .string("fixture-client-credential")]), "body": .string(body)])
  }

  private var biometricChallenge: JSONValue {
    .object(["object": .string("trusted_device_challenge"), "challenge": .string("native_fixture_nonce"), "challenge_id": .string("tdc_native"), "trusted_device_id": .string("td_native"), "client_data": .string("native_fixture_client_data"), "expires_at": .number(Date().timeIntervalSince1970 * 1000 + 600_000), "algorithm": .string("ES256")])
  }
}
