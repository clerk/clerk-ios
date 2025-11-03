//
//  HTTPURLResponse+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 7/25/25.
//

import Foundation

extension HTTPURLResponse {

  /// Returns true if the response represents an error (status code >= 400)
  var isError: Bool {
    return statusCode >= 400
  }

  /// Returns true if the response represents a client error (4xx)
  var isClientError: Bool {
    return statusCode >= 400 && statusCode < 500
  }

  /// Returns true if the response represents a server error (5xx)
  var isServerError: Bool {
    return statusCode >= 500
  }

  /// Returns true if the response represents a successful response (2xx)
  var isSuccess: Bool {
    return statusCode >= 200 && statusCode < 300
  }

  /// Returns true if the response represents a redirection (3xx)
  var isRedirection: Bool {
    return statusCode >= 300 && statusCode < 400
  }

  /// Returns a categorized status type
  var statusType: HTTPStatusType {
    switch statusCode {
    case 100..<200:
      return .informational
    case 200..<300:
      return .success
    case 300..<400:
      return .redirection
    case 400..<500:
      return .clientError
    case 500..<600:
      return .serverError
    default:
      return .unknown
    }
  }

  /// Returns a human-readable description of the status code category
  var statusDescription: String {
    switch statusType {
    case .informational:
      return "Informational (\(statusCode))"
    case .success:
      return "Success (\(statusCode))"
    case .redirection:
      return "Redirection (\(statusCode))"
    case .clientError:
      return "Client Error (\(statusCode))"
    case .serverError:
      return "Server Error (\(statusCode))"
    case .unknown:
      return "Unknown Status (\(statusCode))"
    }
  }
}

enum HTTPStatusType {
  case informational  // 1xx
  case success  // 2xx
  case redirection  // 3xx
  case clientError  // 4xx
  case serverError  // 5xx
  case unknown  // Outside normal range
}
