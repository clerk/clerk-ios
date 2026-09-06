import ClerkJSCore
import Foundation
import Testing

struct ClerkAPITests {
  @Test
  func constructsWithoutLoading() {
    let clerk = Clerk(
      publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk",
      tokenCache: .memory()
    )
    #expect(clerk.client.id == "")
    #expect(clerk.client.sessions.isEmpty)
    #expect(clerk.client.signIn.createdSessionId == nil)
    #expect(clerk.client.signIn.id == nil)
  }

  @Test
  func createParamsEncodeIdentifier() throws {
    let json = try encodeJSON(Clerk.SignIn.CreateParams(identifier: "user@example.com"))
    #expect(json["identifier"] as? String == "user@example.com")
    #expect(json.count == 1)
  }

  @Test
  func prepareFirstFactorParamsEncodeJSNames() throws {
    let withEmail = try encodeJSON(
      Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode, emailAddressId: "idn_1")
    )
    #expect(withEmail["strategy"] as? String == "email_code")
    #expect(withEmail["emailAddressId"] as? String == "idn_1")
    #expect(withEmail.count == 2)

    let strategyOnly = try encodeJSON(Clerk.SignIn.PrepareFirstFactorParams(strategy: .emailCode))
    #expect(strategyOnly["strategy"] as? String == "email_code")
    #expect(strategyOnly["emailAddressId"] == nil)
    #expect(strategyOnly.count == 1)
  }

  @Test
  func attemptFirstFactorParamsEncodeJSNames() throws {
    let json = try encodeJSON(
      Clerk.SignIn.AttemptFirstFactorParams(strategy: .emailCode, code: "424242")
    )
    #expect(json["strategy"] as? String == "email_code")
    #expect(json["code"] as? String == "424242")
    #expect(json.count == 2)
  }

  @Test
  func setActiveParamsEncodeSession() throws {
    let json = try encodeJSON(Clerk.SetActiveParams(session: "sess_1"))
    #expect(json["session"] as? String == "sess_1")
    #expect(json.count == 1)
  }
}

private func encodeJSON(_ value: some Encodable) throws -> [String: Any] {
  let data = try JSONEncoder().encode(value)
  return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
