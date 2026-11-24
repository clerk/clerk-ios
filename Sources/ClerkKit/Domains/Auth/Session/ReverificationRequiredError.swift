//
//  ReverificationRequiredError.swift
//

import Foundation

/// An error that means an action needs the user to verify their identity again before it can run.
///
/// Throw it from your own networking code when your backend rejects a request because the
/// session's verification is too old. Clerk's backend SDKs answer such a request with the body
/// that ``init(responseBody:)`` reads.
///
/// ```swift
/// let (data, response) = try await URLSession.shared.data(for: request)
/// if (response as? HTTPURLResponse)?.statusCode == 403,
///    let error = ReverificationRequiredError(responseBody: data) {
///   throw error
/// }
/// ```
///
/// ClerkKitUI's `clerk.reverify` catches this error, asks the user to verify, and runs the
/// action again.
public struct ReverificationRequiredError: Error, Equatable, Sendable {
  /// How recently the rejected request needs the user to have verified, when it says.
  ///
  /// `nil` means the request didn't say, as when Clerk's own API answers with
  /// `session_reverification_required`.
  public var reverification: ReverificationConfig?

  /// Creates an error that asks for `reverification`.
  public init(reverification: ReverificationConfig? = nil) {
    self.reverification = reverification
  }

  /// Reads the reverification error body that Clerk's backend SDKs send with a 403 response.
  ///
  /// The body looks like
  /// `{"clerk_error": {"type": "forbidden", "reason": "reverification-error", "metadata": {"reverification": "strict"}}}`,
  /// where `reverification` is `strict_mfa`, `strict`, `moderate`, `lax`, or an object with
  /// `level` and `afterMinutes`. Returns `nil` for any other body.
  public init?(responseBody: Data) {
    guard
      let body = try? JSONDecoder().decode(JSON.self, from: responseBody),
      let clerkError = body["clerk_error"],
      clerkError["type"]?.stringValue == "forbidden",
      clerkError["reason"]?.stringValue == "reverification-error"
    else {
      return nil
    }

    self.init(reverification: clerkError["metadata"]?["reverification"].flatMap(Self.reverificationConfig))
  }

  /// Returns the reverification `error` asks for, or `nil` when it doesn't ask for one.
  ///
  /// Recognizes a ``ReverificationRequiredError`` and a ``ClerkAPIError`` with the code
  /// `session_reverification_required`.
  public init?(_ error: any Error) {
    if let error = error as? ReverificationRequiredError {
      self = error
    } else if let error = error as? ClerkAPIError, error.code == "session_reverification_required" {
      self.init()
    } else {
      return nil
    }
  }

  private static func reverificationConfig(_ json: JSON) -> ReverificationConfig? {
    if let name = json.stringValue {
      return switch name {
      case "strict_mfa": .strictMfa
      case "strict": .strict
      case "moderate": .moderate
      case "lax": .lax
      default: nil
      }
    }

    guard
      let levelName = json["level"]?.stringValue,
      let afterMinutes = json["afterMinutes"]?.doubleValue
    else {
      return nil
    }

    let config = ReverificationConfig.custom(
      level: SessionVerification.Level(rawValue: levelName),
      afterMinutes: Int(afterMinutes)
    )
    return config.requirement == nil ? nil : config
  }
}
