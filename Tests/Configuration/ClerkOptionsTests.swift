//
//  ClerkOptionsTests.swift
//

@testable import ClerkKit
import Foundation
import Testing

@Suite(.serialized)
struct ClerkOptionsTests {
  private struct TestRequestMiddleware: ClerkRequestMiddleware {
    func prepare(_: inout URLRequest) async throws {}
  }

  private struct TestResponseMiddleware: ClerkResponseMiddleware {
    func validate(_: HTTPURLResponse, data _: Data, for _: URLRequest) async throws {}
  }

  @Test
  func defaultInitialization() {
    let options = Clerk.Options()

    #expect(options.logLevel == .error)
    #expect(options.telemetryEnabled == true)
    #expect(options.proxyUrl == nil)
    #expect(options.keychainConfig.service == Bundle.main.bundleIdentifier ?? "")
    #expect(options.keychainConfig.accessGroup == nil)
    #expect(options.redirectConfig.redirectUrl.contains("://callback"))
    #expect(options.redirectConfig.callbackUrlScheme == Bundle.main.bundleIdentifier ?? "")
    #expect(options.middleware.request.isEmpty == true)
    #expect(options.middleware.response.isEmpty == true)
  }

  @Test
  func initializationWithAllParameters() {
    let keychainConfig = Clerk.Options.KeychainConfig(service: "test.service", accessGroup: "test.group")
    let redirectConfig = Clerk.Options.RedirectConfig(redirectUrl: "test://redirect", callbackUrlScheme: "test")

    let options = Clerk.Options(
      logLevel: .debug,
      telemetryEnabled: false,
      keychainConfig: keychainConfig,
      proxyUrl: "https://proxy.example.com/__clerk",
      redirectConfig: redirectConfig
    )

    #expect(options.logLevel == .debug)
    #expect(options.telemetryEnabled == false)
    #expect(options.keychainConfig.service == "test.service")
    #expect(options.keychainConfig.accessGroup == "test.group")
    #expect(options.proxyUrl?.absoluteString == "https://proxy.example.com/__clerk")
    #expect(options.redirectConfig.redirectUrl == "test://redirect")
    #expect(options.redirectConfig.callbackUrlScheme == "test")
  }

  @Test
  func proxyUrlConversionValidURL() {
    let options = Clerk.Options(proxyUrl: "https://proxy.example.com/__clerk")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.scheme == "https")
    #expect(options.proxyUrl?.host == "proxy.example.com")
    #expect(options.proxyUrl?.path == "/__clerk")
  }

  @Test
  func proxyUrlConversionInvalidURL() {
    let options = Clerk.Options(proxyUrl: "https://proxy example.com/__clerk")

    #expect(options.proxyUrl == nil)
  }

  @Test
  func proxyUrlConversionNil() {
    let options = Clerk.Options(proxyUrl: nil)

    #expect(options.proxyUrl == nil)
  }

  @Test
  func proxyUrlConversionWithPort() {
    let options = Clerk.Options(proxyUrl: "https://proxy.example.com:8080/__clerk")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.port == 8080)
  }

  @Test
  func proxyUrlConversionWithQueryParams() {
    let options = Clerk.Options(proxyUrl: "https://proxy.example.com/__clerk?param=value")

    #expect(options.proxyUrl != nil)
    #expect(options.proxyUrl?.query == "param=value")
  }

  @Test
  func partialInitialization() {
    let options = Clerk.Options(logLevel: .debug)

    #expect(options.logLevel == .debug)
    #expect(options.telemetryEnabled == true)
    #expect(options.proxyUrl == nil)
  }

  @Test
  func requestMiddlewareInitialization() {
    let middleware = TestRequestMiddleware()
    let options = Clerk.Options(middleware: .init(request: [middleware]))

    #expect(options.middleware.request.count == 1)
    #expect(options.middleware.request.first is TestRequestMiddleware)
  }

  @Test
  func responseMiddlewareInitialization() {
    let middleware = TestResponseMiddleware()
    let options = Clerk.Options(middleware: .init(response: [middleware]))

    #expect(options.middleware.response.count == 1)
    #expect(options.middleware.response.first is TestResponseMiddleware)
  }
}
