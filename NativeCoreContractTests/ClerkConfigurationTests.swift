import ClerkKit
import Foundation
import Testing

struct ClerkConfigurationTests {
  private func key(_ value: String, mode: String = "test") -> String {
    "pk_\(mode)_" + Data(value.utf8).base64EncodedString()
  }

  @Test(arguments: ["test", "live"])
  func validKeysNormalizeWhitespaceAndPreserveTheConfiguredCallback(mode: String) throws {
    let publishableKey = key("clerk.example.com$", mode: mode)
    let callback = try #require(URL(string: "app.clerk://oauth/callback?source=app"))
    let configuration = try ClerkConfiguration(publishableKey: "  \(publishableKey)\n", callbackURL: callback)
    #expect(configuration.publishableKey == publishableKey)
    #expect(configuration.frontendAPI.absoluteString == "https://clerk.example.com")
    #expect(configuration.callbackURL == callback)
  }

  @Test func invalidPublishableKeysProduceStructuredErrors() throws {
    let malformed = ["", "   ", "invalid", "pk_invalid_something", "pk_test_!!!", Data("clerk.example.com$".utf8).base64EncodedString()] + [
      "", "x", "clerk.example.com", "clerk.example.comx", "user@clerk.example.com$", "clerk.example.com/path$",
      "clerk.example.com?query$", "clerk.example.com#fragment$", "bad host$", "[broken$",
    ].map { key($0) }
    let callback = try #require(URL(string: "app.clerk://oauth/callback"))
    for value in malformed {
      do {
        _ = try ClerkConfiguration(publishableKey: value, callbackURL: callback)
        Issue.record("Accepted malformed publishable key")
      } catch let error as CoreError {
        #expect(error.code == "invalid_publishable_key")
      }
    }
  }

  @Test(arguments: [
    "relative", "http://example.com/callback", "HTTP://example.com/callback",
    "file://example.com/callback", "javascript://example.com/callback",
    "app.clerk://user@example.com/callback", "app.clerk://oauth/callback#fragment",
  ])
  func invalidCallbackRoutesProduceStructuredErrors(callback: String) throws {
    let url = try #require(URL(string: callback))
    do {
      _ = try ClerkConfiguration(publishableKey: key("clerk.example.com$"), callbackURL: url)
      Issue.record("Accepted malformed callback")
    } catch let error as CoreError {
      #expect(error.code == "invalid_callback_url")
    }
  }

  @Test func httpsCallbacksAreAcceptedForPlatformsSupportingVerifiedLinks() throws {
    let callback = try #require(URL(string: "https://example.com/callback"))
    let configuration = try ClerkConfiguration(publishableKey: key("clerk.example.com$"), callbackURL: callback)
    #expect(configuration.callbackURL == callback)
  }
}
