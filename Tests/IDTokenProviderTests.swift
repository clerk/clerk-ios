import Foundation
import Testing

@testable import Clerk

struct IDTokenProviderTests {
  
  @Test func testSuccessfulInit() {
    let provider = IDTokenProvider(strategy: "oauth_token_apple")
    #expect(provider == .apple)
  }
  
  @Test func testFailedInit() {
    let invalidProvider = IDTokenProvider(strategy: "oauth_token_invalid")
    #expect(invalidProvider == nil)
  }
  
}
