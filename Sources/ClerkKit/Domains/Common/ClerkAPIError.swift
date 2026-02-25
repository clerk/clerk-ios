//
//  ClerkAPIError.swift
//  Clerk
//

import Foundation

/// An object that represents an error returned by the Clerk API.
public struct ClerkAPIError: Error, LocalizedError, Codable, Equatable, Hashable, ClerkError {
  /// A string code that represents the error, such as `username_exists_code`.
  public var code: String

  /// A message that describes the error.
  public var message: String?

  /// A more detailed message that describes the error.
  public var longMessage: String?

  /// Additional information about the error.
  public var meta: JSON?

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?

  /// Additional context about the error, including trace ID and parameter name if available.
  public var context: [String: String]? {
    var ctx: [String: String] = [:]
    if let clerkTraceId {
      ctx["traceId"] = clerkTraceId
    }
    if let paramName = meta?["param_name"]?.stringValue {
      ctx["paramName"] = paramName
    }
    return ctx.isEmpty ? nil : ctx
  }
}

extension ClerkAPIError {
  public var errorDescription: String? {
    longMessage ?? message
  }
}

/// Represents the body of Clerk API error responses.
///
/// The `ClerkErrorResponse` structure encapsulates multiple API errors that may occur during a request.
/// It also includes a unique trace ID for debugging purposes.
public struct ClerkErrorResponse: Codable, Equatable {
  /// An array of `ClerkAPIError` objects, each describing an individual error.
  public var errors: [ClerkAPIError]

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?
}

extension ClerkAPIError {
  package enum Code: String, Sendable {
    case unsupportedAppVersion = "unsupported_app_version"
    case requiresAssertion = "requires_assertion"
    case requiresDeviceAttestation = "requires_device_attestation"
    case verificationAlreadyVerified = "verification_already_verified"
    case formIdentifierNotFound = "form_identifier_not_found"
    case invitationAccountNotExists = "invitation_account_not_exists"
    case authenticationInvalid = "authentication_invalid"
    case resourceNotFound = "resource_not_found"
  }

  package var apiCode: Code? {
    Code(rawValue: code)
  }
}
