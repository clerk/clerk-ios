//
//  RequestTestHelpers.swift
//  Clerk
//
//  Created by Mike Pitre on 1/1/26.
//

import Foundation

/// Parses URL-encoded form data from a Data object.
func parseURLEncodedForm(_ data: Data) -> [String: String] {
  guard let bodyString = String(data: data, encoding: .utf8) else {
    return [:]
  }

  var parameters: [String: String] = [:]
  let pairs = bodyString.split(separator: "&")

  for pair in pairs {
    let keyValue = pair.split(separator: "=", maxSplits: 1)
    if keyValue.count == 2 {
      let key = keyValue[0].removingPercentEncoding ?? String(keyValue[0])
      let value = keyValue[1].removingPercentEncoding ?? String(keyValue[1])
      parameters[key] = value
    }
  }

  return parameters
}

/// Parses URL-encoded form data from a URLRequest.
func parseURLEncodedForm(from request: URLRequest) -> [String: String] {
  guard let body = request.httpBody else {
    return [:]
  }
  return parseURLEncodedForm(body)
}

/// Parses JSON data from a Data object.
func parseJSON(_ data: Data) throws -> [String: Any] {
  guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    return [:]
  }
  return json
}

/// Parses JSON data from a URLRequest.
func parseJSON(from request: URLRequest) throws -> [String: Any] {
  guard let body = request.httpBody else {
    return [:]
  }
  return try parseJSON(body)
}

/// Extracts query parameters from a URLRequest.
func getQueryParameters(from request: URLRequest) -> [String: String] {
  guard let url = request.url,
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
    let queryItems = components.queryItems
  else {
    return [:]
  }

  var parameters: [String: String] = [:]
  for item in queryItems {
    if let value = item.value {
      parameters[item.name] = value
    }
  }

  return parameters
}

/// Finds the last request matching a path pattern
func findLastRequest(matchingPath path: String, from requests: [URLRequest]) -> URLRequest? {
  requests.last { request in
    guard let url = request.url else { return false }
    return url.path == path || url.path.hasSuffix(path)
  }
}

/// Verifies that a URLRequest has the expected properties.
struct RequestVerification {
  let url: URLRequest

  func hasPath(_ expectedPath: String) -> Bool {
    guard let url = url.url else { return false }
    let path = url.path
    return path == expectedPath || path.hasSuffix(expectedPath)
  }

  func hasMethod(_ expectedMethod: String) -> Bool {
    return url.httpMethod?.uppercased() == expectedMethod.uppercased()
  }

  func hasHeader(_ name: String, value: String?) -> Bool {
    let headerValue = url.value(forHTTPHeaderField: name)
    if let expectedValue = value {
      return headerValue == expectedValue
    }
    return headerValue != nil
  }

  func hasQueryParameter(_ name: String, value: String?) -> Bool {
    let params = getQueryParameters(from: url)
    if let expectedValue = value {
      return params[name] == expectedValue
    }
    return params[name] != nil
  }

  func hasURLEncodedFormParameter(_ name: String, value: String?) -> Bool {
    let params = parseURLEncodedForm(from: url)
    if let expectedValue = value {
      return params[name] == expectedValue
    }
    return params[name] != nil
  }

  func hasContentType(_ expectedType: String) -> Bool {
    return hasHeader("Content-Type", value: expectedType)
  }
}
