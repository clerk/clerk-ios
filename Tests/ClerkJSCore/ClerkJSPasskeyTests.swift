#if !os(watchOS)
import AuthenticationServices
@testable import ClerkJSCore
import Foundation
import Testing

struct ClerkJSPasskeyTests {
  @Test
  func parseCreateReadsWebAuthnFields() throws {
    let challenge = Data("challenge".utf8)
    let userID = Data("user".utf8)
    let excluded = Data([0x01, 0x02])
    let payload = """
      {
        "challenge": "\(ClerkJSPasskeyCeremony.base64URL(from: challenge))",
        "rpId": "example.com",
        "userId": "\(ClerkJSPasskeyCeremony.base64URL(from: userID))",
        "displayName": "Ada",
        "excludeCredentials": ["\(ClerkJSPasskeyCeremony.base64URL(from: excluded))"]
      }
      """
    let options = try ClerkJSPasskeyCeremony.parseCreate(payload).get()
    #expect(options.challenge == challenge)
    #expect(options.relyingPartyID == "example.com")
    #expect(options.userID == userID)
    #expect(options.displayName == "Ada")
    #expect(options.excludeCredentials == [excluded])
  }

  @Test
  func parseCreateRejectsMissingRpId() {
    let result = ClerkJSPasskeyCeremony.parseCreate(#"{"challenge":"YQ","userId":"YQ"}"#)
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "passkey_registration_failed")
  }

  @Test
  func parseGetReadsAllowCredentials() throws {
    let challenge = Data("get-challenge".utf8)
    let allowed = Data([0xAA, 0xBB])
    let payload = """
      {
        "challenge": "\(ClerkJSPasskeyCeremony.base64URL(from: challenge))",
        "rpId": "clerk.com",
        "allowCredentials": ["\(ClerkJSPasskeyCeremony.base64URL(from: allowed))"],
        "conditionalUI": true,
        "preferImmediatelyAvailableCredentials": false
      }
      """
    let options = try ClerkJSPasskeyCeremony.parseGet(payload).get()
    #expect(options.challenge == challenge)
    #expect(options.relyingPartyID == "clerk.com")
    #expect(options.allowCredentials == [allowed])
    #expect(options.conditionalUI)
    #expect(!options.preferImmediatelyAvailableCredentials)
  }

  @Test
  func parseGetRejectsInvalidJSON() {
    let result = ClerkJSPasskeyCeremony.parseGet("not-json")
    guard case .failure(let error) = result else {
      Issue.record("Expected parse failure")
      return
    }
    #expect(error.code == "passkey_retrieval_failed")
  }

  @Test
  func registrationJSONUsesBase64URL() throws {
    let json = ClerkJSPasskeyCeremony.registrationJSON(
      credentialID: Data([0xFB, 0xEF]),
      attestationObject: Data("attest".utf8),
      clientDataJSON: Data("client".utf8)
    )
    #expect(json["id"] as? String == "--8")
    #expect(json["rawId"] as? String == "--8")
    #expect(json["type"] as? String == "public-key")
    let response = try #require(json["response"] as? [String: Any])
    #expect(response["attestationObject"] as? String == ClerkJSPasskeyCeremony.base64URL(from: Data("attest".utf8)))
    #expect(response["clientDataJSON"] as? String == ClerkJSPasskeyCeremony.base64URL(from: Data("client".utf8)))
  }

  @Test
  func assertionJSONIncludesUserHandle() throws {
    let json = ClerkJSPasskeyCeremony.assertionJSON(
      credentialID: Data([0x01]),
      authenticatorData: Data("auth".utf8),
      clientDataJSON: Data("client".utf8),
      signature: Data("sig".utf8),
      userID: Data("handle".utf8)
    )
    let response = try #require(json["response"] as? [String: Any])
    #expect(response["userHandle"] as? String == ClerkJSPasskeyCeremony.base64URL(from: Data("handle".utf8)))
    #expect(response["signature"] as? String == ClerkJSPasskeyCeremony.base64URL(from: Data("sig".utf8)))
  }

  @Test
  func mapsCanceledAuthorizationToActionCodes() {
    let create = ClerkJSPasskeyError.from(ASAuthorizationError(.canceled), action: .create)
    #expect(create.code == "passkey_registration_cancelled")
    let get = ClerkJSPasskeyError.from(ASAuthorizationError(.canceled), action: .get)
    #expect(get.code == "passkey_retrieval_cancelled")
  }

  @Test
  func mapsInvalidResponseToRpIdCode() {
    let error = ClerkJSPasskeyError.from(ASAuthorizationError(.invalidResponse), action: .get)
    #expect(error.code == "passkey_invalid_rpID_or_domain")
  }
}
#endif
