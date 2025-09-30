import Foundation
import RegexBuilder

final class ConfigurationStore {
  private(set) var publishableKey: String = ""
  private(set) var frontendAPIURL: URL?

  func configure(publishableKey: String) {
    self.publishableKey = publishableKey
    frontendAPIURL = Self.makeFrontendAPIURL(from: publishableKey)
  }
}

private extension ConfigurationStore {
  static func makeFrontendAPIURL(from publishableKey: String) -> URL? {
    guard !publishableKey.isEmpty else {
      return nil
    }

    let liveRegex = Regex {
      "pk_live_"
      Capture {
        OneOrMore(.any)
      }
    }

    let testRegex = Regex {
      "pk_test_"
      Capture {
        OneOrMore(.any)
      }
    }

    guard let match = publishableKey.firstMatch(of: liveRegex)?.output.1
      ?? publishableKey.firstMatch(of: testRegex)?.output.1,
      let decoded = String(match).base64String()
    else {
      Logger.log(level: .warning, message: "Failed to make frontend API URL from publishable key")
      return nil
    }

    let trimmed = String(decoded.dropLast())
    return URL(string: "https://\(trimmed)")
  }
}
