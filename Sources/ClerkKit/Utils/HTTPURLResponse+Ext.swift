//
//  HTTPURLResponse+Ext.swift
//  Clerk
//

import Foundation

extension HTTPURLResponse {
  /// Returns true if the response represents an error (status code >= 400)
  var isError: Bool {
    statusCode >= 400
  }

  /// Returns true if the response represents a client error (4xx)
  var isClientError: Bool {
    statusCode >= 400 && statusCode < 500
  }

  /// Returns true if the response represents a server error (5xx)
  var isServerError: Bool {
    statusCode >= 500
  }

  /// Returns true if the response represents a successful response (2xx)
  var isSuccess: Bool {
    statusCode >= 200 && statusCode < 300
  }

  /// Returns true if the response represents a redirection (3xx)
  var isRedirection: Bool {
    statusCode >= 300 && statusCode < 400
  }

  /// Returns a categorized status type
  var statusType: HTTPStatusType {
    switch statusCode {
    case 100 ..< 200:
      .informational
    case 200 ..< 300:
      .success
    case 300 ..< 400:
      .redirection
    case 400 ..< 500:
      .clientError
    case 500 ..< 600:
      .serverError
    default:
      .unknown
    }
  }

  /// Returns a human-readable description of the status code category
  var statusDescription: String {
    switch statusType {
    case .informational:
      "Informational (\(statusCode))"
    case .success:
      "Success (\(statusCode))"
    case .redirection:
      "Redirection (\(statusCode))"
    case .clientError:
      "Client Error (\(statusCode))"
    case .serverError:
      "Server Error (\(statusCode))"
    case .unknown:
      "Unknown Status (\(statusCode))"
    }
  }
}

enum HTTPStatusType {
  /// 1xx status codes.
  case informational
  /// 2xx status codes.
  case success
  /// 3xx status codes.
  case redirection
  /// 4xx status codes.
  case clientError
  /// 5xx status codes.
  case serverError
  /// Status codes outside the 1xx-5xx range.
  case unknown
}
