import Foundation
import Testing

@testable import Clerk

@Suite("ExternalAuthUtilsTests")
struct ExternalAuthUtilsTests {
  
  @Test func testExtractRotatingTokenNonceFromUrl() {
    let nonce = UUID().uuidString
    var components = URLComponents(url: mockBaseUrl, resolvingAgainstBaseURL: false)!
    components.path.append("/v1/client/sign_ins/sia_1")
    components.queryItems = [.init(name: "rotating_token_nonce", value: nonce), .init(name: "_is_native", value: "true")]
    let url = components.url!
    let extractedNonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    #expect(extractedNonce == nonce)
  }
  
  @Test func testExtractRotatingTokenNonceFromUrlShouldReturnNil() {
    // Missing Query Item
    var components = URLComponents(url: mockBaseUrl, resolvingAgainstBaseURL: false)!
    components.path.append("/v1/client/sign_ins/sia_1")
    components.queryItems = [.init(name: "_is_native", value: "true")]
    let url = components.url!
    let extractedNonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    #expect(extractedNonce == nil)
  }
  
}
