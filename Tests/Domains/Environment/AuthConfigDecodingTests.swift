@testable import ClerkKit
import Foundation
import Testing

struct AuthConfigDecodingTests {
  private let decoder = JSONDecoder.clerkDecoder

  @Test
  func sessionMinterDefaultsToFalseWhenKeyIsMissing() throws {
    let data = Data("{ \"single_session_mode\": false }".utf8)
    let authConfig = try decoder.decode(Clerk.Environment.AuthConfig.self, from: data)

    #expect(authConfig.sessionMinter == false)
  }

  @Test
  func sessionMinterDecodesFromSnakeCaseKey() throws {
    let data = Data("{ \"single_session_mode\": false, \"session_minter\": true }".utf8)
    let authConfig = try decoder.decode(Clerk.Environment.AuthConfig.self, from: data)

    #expect(authConfig.sessionMinter == true)
  }
}
