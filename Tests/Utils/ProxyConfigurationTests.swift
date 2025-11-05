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
  func initWithValidURL() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.baseURL.absoluteString == "https://proxy.example.com")
      #expect(config.pathSegments == ["__clerk"])
    }
  }

  @Test
  func initWithNilURL() {
    let config = ProxyConfiguration(url: nil)
    #expect(config == nil)
  }

  @Test
  func initWithURLWithoutScheme() {
    let url = URL(string: "proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func initWithURLWithoutHost() {
    let url = URL(string: "https:///__clerk")!
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func initWithURLWithPort() {
    let url = URL(string: "https://proxy.example.com:8080/__clerk")!
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.baseURL.port == 8080)
      #expect(config.pathSegments == ["__clerk"])
    }
  }

  @Test
  func initWithURLWithoutPath() {
    let url = URL(string: "https://proxy.example.com")!
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func initWithURLWithRootPath() {
    let url = URL(string: "https://proxy.example.com/")!
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func initWithURLWithMultiplePathSegments() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1/api")!
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == ["__clerk", "v1", "api"])
    }
  }

  @Test
  func prefixedPathWithEmptyPathSegments() {
    let url = URL(string: "https://proxy.example.com")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/v1/client")
  }

  @Test
  func prefixedPathWithSimplePath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithPathAlreadyPrefixed() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!

    // Path already starts with proxy segments
    let result = config.prefixedPath(for: "/__clerk/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithPathWithoutLeadingSlash() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithMultipleProxySegments() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithEmptyOriginalPath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "")
    #expect(result == "/__clerk")
  }

  @Test
  func prefixedPathWithRootPath() {
    let url = URL(string: "https://proxy.example.com/__clerk")!
    let config = ProxyConfiguration(url: url)!

    let result = config.prefixedPath(for: "/")
    #expect(result == "/__clerk")
  }

  @Test
  func prefixedPathWithPartialMatch() {
    let url = URL(string: "https://proxy.example.com/__clerk/v1")!
    let config = ProxyConfiguration(url: url)!

    // Path doesn't start with all proxy segments
    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/v1/client")
  }
}
