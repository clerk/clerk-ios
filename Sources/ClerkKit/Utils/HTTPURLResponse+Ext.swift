//
//  HTTPURLResponse+Ext.swift
//  Clerk
//

import Foundation

extension HTTPURLResponse {
  var isError: Bool {
    statusCode >= 400
  }

  var isClientError: Bool {
    statusCode >= 400 && statusCode < 500
  }

  var isServerError: Bool {
    statusCode >= 500
  }

  var isSuccess: Bool {
    statusCode >= 200 && statusCode < 300
  }

  var isRedirection: Bool {
    statusCode >= 300 && statusCode < 400
  }

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
  case informational
  case success
  case redirection
  case clientError
  case serverError
  case unknown
}
