@testable import ClerkKit
import Foundation
import Testing

struct AuthConfigTests {
  @Test
  func decodesSessionMinter() throws {
    let data = Data(
      #"{"single_session_mode":false,"session_minter":true}"#.utf8
    )

    let authConfig = try JSONDecoder.clerkDecoder.decode(
      Clerk.Environment.AuthConfig.self,
      from: data
    )

    #expect(authConfig.sessionMinter)
  }

  @Test
  func defaultsSessionMinterToFalseWhenMissing() throws {
    let data = Data(#"{"single_session_mode":false}"#.utf8)

    let authConfig = try JSONDecoder.clerkDecoder.decode(
      Clerk.Environment.AuthConfig.self,
      from: data
    )

    #expect(authConfig.sessionMinter == false)
  }
}
