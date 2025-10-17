import Foundation
import Testing

@testable import Clerk

struct ProxyConfigurationTests {

    @Test
    func testBaseUrlDropsPath() {
        let config = ProxyConfiguration(url: URL(string: "https://api.example.com/__clerk")!)
        #expect(config?.baseURL.absoluteString == "https://api.example.com")
        #expect(config?.pathSegments == ["__clerk"])
    }

    @Test
    func testPrefixedPathAddsSegments() {
        let config = ProxyConfiguration(url: URL(string: "https://api.example.com/__clerk")!)!
        let result = config.prefixedPath(for: "/v1/client")
        #expect(result == "/__clerk/v1/client")
    }

    @Test
    func testPrefixedPathIsIdempotent() {
        let config = ProxyConfiguration(url: URL(string: "https://api.example.com/__clerk")!)!
        let alreadyPrefixed = "/__clerk/v1/client"
        #expect(config.prefixedPath(for: alreadyPrefixed) == alreadyPrefixed)
    }

    @Test
    func testPrefixedPathWithMultipleSegments() {
        let config = ProxyConfiguration(url: URL(string: "https://api.example.com/foo/bar/__clerk")!)!
        let result = config.prefixedPath(for: "/v1/client")
        #expect(result == "/foo/bar/__clerk/v1/client")
        let alreadyPrefixed = "/foo/bar/__clerk/v1/client"
        #expect(config.prefixedPath(for: alreadyPrefixed) == alreadyPrefixed)
    }

    @Test
    func testRelativeUrlReturnsNil() {
        let config = ProxyConfiguration(url: URL(string: "/__clerk"))
        #expect(config == nil)
    }
}
