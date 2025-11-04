//
//  ExternalAuthUtilsTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ExternalAuthUtilsTests {

  @Test
  func testNonceFromCallbackUrlWithNonce() {
    let urlString = "https://example.com/callback?rotating_token_nonce=abc123&other=param"
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == "abc123")
  }

  @Test
  func testNonceFromCallbackUrlWithoutNonce() {
    let urlString = "https://example.com/callback?other=param&another=value"
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == nil)
  }

  @Test
  func testNonceFromCallbackUrlWithMultipleQueryParams() {
    let urlString = "https://example.com/callback?first=value&rotating_token_nonce=xyz789&last=value"
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == "xyz789")
  }

  @Test
  func testNonceFromCallbackUrlWithEmptyNonce() {
    let urlString = "https://example.com/callback?rotating_token_nonce="
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == "")
  }

  @Test
  func testNonceFromCallbackUrlWithoutQueryParams() {
    let urlString = "https://example.com/callback"
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == nil)
  }

  @Test
  func testNonceFromCallbackUrlWithFragment() {
    // Query params should still work even with fragment
    let urlString = "https://example.com/callback?rotating_token_nonce=test123#fragment"
    let url = URL(string: urlString)!
    
    let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url)
    
    #expect(nonce == "test123")
  }
}

