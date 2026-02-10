//
//  ProxyConfigurationTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct ProxyConfigurationTests {
  @Test
  func initWithValidURL() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
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
  func initWithURLWithoutScheme() throws {
    let url = try #require(URL(string: "proxy.example.com/__clerk"))
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func initWithURLWithoutHost() throws {
    let url = try #require(URL(string: "https:///__clerk"))
    let config = ProxyConfiguration(url: url)
    #expect(config == nil)
  }

  @Test
  func initWithURLWithPort() throws {
    let url = try #require(URL(string: "https://proxy.example.com:8080/__clerk"))
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.baseURL.port == 8080)
      #expect(config.pathSegments == ["__clerk"])
    }
  }

  @Test
  func initWithURLWithoutPath() throws {
    let url = try #require(URL(string: "https://proxy.example.com"))
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func initWithURLWithRootPath() throws {
    let url = try #require(URL(string: "https://proxy.example.com/"))
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == [])
    }
  }

  @Test
  func initWithURLWithMultiplePathSegments() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk/v1/api"))
    let config = ProxyConfiguration(url: url)

    #expect(config != nil)
    if let config {
      #expect(config.pathSegments == ["__clerk", "v1", "api"])
    }
  }

  @Test
  func prefixedPathWithEmptyPathSegments() throws {
    let url = try #require(URL(string: "https://proxy.example.com"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/v1/client")
  }

  @Test
  func prefixedPathWithSimplePath() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithPathAlreadyPrefixed() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
    let config = try #require(ProxyConfiguration(url: url))

    // Path already starts with proxy segments
    let result = config.prefixedPath(for: "/__clerk/v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithPathWithoutLeadingSlash() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "v1/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithMultipleProxySegments() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk/v1"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "/client")
    #expect(result == "/__clerk/v1/client")
  }

  @Test
  func prefixedPathWithEmptyOriginalPath() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "")
    #expect(result == "/__clerk")
  }

  @Test
  func prefixedPathWithRootPath() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk"))
    let config = try #require(ProxyConfiguration(url: url))

    let result = config.prefixedPath(for: "/")
    #expect(result == "/__clerk")
  }

  @Test
  func prefixedPathWithPartialMatch() throws {
    let url = try #require(URL(string: "https://proxy.example.com/__clerk/v1"))
    let config = try #require(ProxyConfiguration(url: url))

    // Path doesn't start with all proxy segments
    let result = config.prefixedPath(for: "/v1/client")
    #expect(result == "/__clerk/v1/v1/client")
  }
}
