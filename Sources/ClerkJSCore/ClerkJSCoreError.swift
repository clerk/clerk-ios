import Foundation

public enum ClerkJSCoreError: Error, Sendable, Equatable {
  case unsupportedPlatform
  case missingBundle
  case javascript(String)
  case invalidArgument(String)
  case cancelled
}
