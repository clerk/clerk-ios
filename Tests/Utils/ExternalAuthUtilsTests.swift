//
//  ExternalAuthUtilsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct ExternalAuthUtilsTests {
  @Test
  func nonceFromCallbackUrlWithNonce() throws {
    let urlString = "https://example.com/callback?rotating_token_nonce=abc123&other=param"
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == "abc123")
  }

  @Test
  func nonceFromCallbackUrlWithoutNonce() throws {
    let urlString = "https://example.com/callback?other=param&another=value"
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == nil)
  }

  @Test
  func nonceFromCallbackUrlWithMultipleQueryParams() throws {
    let urlString = "https://example.com/callback?first=value&rotating_token_nonce=xyz789&last=value"
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == "xyz789")
  }

  @Test
  func nonceFromCallbackUrlWithEmptyNonce() throws {
    let urlString = "https://example.com/callback?rotating_token_nonce="
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == "")
  }

  @Test
  func nonceFromCallbackUrlWithoutQueryParams() throws {
    let urlString = "https://example.com/callback"
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == nil)
  }

  @Test
  func nonceFromCallbackUrlWithFragment() throws {
    // Query params should still work even with fragment
    let urlString = "https://example.com/callback?rotating_token_nonce=test123#fragment"
    let url = try #require(URL(string: urlString))

    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)

    #expect(nonce == "test123")
  }
}
