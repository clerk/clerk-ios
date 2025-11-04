//
//  ProxyConfigurationTests.swift
//
//
//  Created by Assistant on 2025-01-27.
//

import Foundation
import Testing

@testable import ClerkKit

@Suite(.serialized)
struct ProxyConfigurationTests {

  @Test
  func testInitWithValidURL() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)
    
    #expect(config != nil)
    if let config = config {
      #expect(config.baseURL.absoluteString == "https://proxy.example.com")
      #expect(config.pathSegments == ["__clerk"])
    }
  }

  @Test
  func testInitWithNilURL() {
    let config = ProxyConfiguration(url: nil)
    #expect(config == nil)
  }

  @Test
  func testInitWithURLWithoutScheme() {
    let url = URL(string: "proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func testInitWithURLWithoutHost() {
    let url = URL(string: "https:///__clerk")!
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func testInitWithURLWithPort() {
    let url = URL(string: "https://proxy.example.com:8080/__clerk")!
    let config = ProxyConfiguration(url: url)
    
    #expect(config != nil)
    if let config = config {
      #expect(config.baseURL.port == 8080)
      #expect(config.pathSegments == ["__clerk"])
    }
  }

  @Test
  func testInitWithURLWithoutPath() {
    let url = URL(string: "https://proxy.example.com")!
    let config = ProxyConfiguration(url: url)
    
    #expect(config != nil)
    if let config = config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func testInitWithURLWithRootPath() {
    let url = URL(string: "https://proxy.example.com/")!
    let config = ProxyConfiguration(url: url)
    
    #expect(config != nil)
    if let config = config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func testInitWithURLWithMultiplePathSegments() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1/api")!
    let config = ProxyConfiguration(url: url)
    
    #expect(config != nil)
    if let config = config {
      #expect(config.pathSegments == ["__clerk", "v1", "api"])
    }
  }

  @Test
  func testPrefixedPathWithEmptyPathSegments() {
    let url = URL(string: "https://proxy.example.com")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/v1/client")
  }

  @Test
  func testPrefixedPathWithSimplePath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func testPrefixedPathWithPathAlreadyPrefixed() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!
    
    // Path already starts with proxy segments
    let result = config.prefixedPath(for: "/__clerk/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func testPrefixedPathWithPathWithoutLeadingSlash() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func testPrefixedPathWithMultipleProxySegments() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func testPrefixedPathWithEmptyOriginalPath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "")
    #expect(result == "/__clerk")
  }

  @Test
  func testPrefixedPathWithRootPath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!
    
    let result = config.prefixedPath(for: "/")
    #expect(result == "/__clerk")
  }

  @Test
  func testPrefixedPathWithPartialMatch() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1")!
    let config = ProxyConfiguration(url: url)!
    
    // Path doesn't start with all proxy segments
    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/v1/client")
  }
}

