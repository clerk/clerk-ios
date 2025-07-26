//
//  URLRequestBuilder+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation
import RequestBuilder

extension URLRequestBuilder {

  /// Adds the current Clerk session id to request URL.
  @discardableResult
  func addClerkSessionId() -> Self {
    map {
      guard let sessionId = try? loadClientFromKeychain()?.lastActiveSessionId else {
        return
      }
      
      if let url = request.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        components.queryItems = (components.queryItems ?? []) + [.init(name: "_clerk_session_id", value: sessionId)]
        $0.request.url = components.url
      }
    }
  }
  
  func loadClientFromKeychain() throws -> Client? {
    guard let clientData = try? Container.shared.keychain().data(forKey: "cachedClient") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Client.self, from: clientData)
  }

  /// Given an encodable data type, sets the request body to x-www-form-urlencoded data .
  @discardableResult
  public func body<DataType: Encodable>(formEncode data: DataType, encoder: DataEncoder? = nil) -> Self {
    let encoder = encoder ?? manager.encoder
    return map {
      do {
        // Encode to JSON data first
        let jsonData = try encoder.encode(data)

        // Convert JSON data to dictionary
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
          let stringDict = jsonObject.compactMapValues { value -> String? in
            if let string = value as? String {
              return string
            } else if let number = value as? NSNumber {
              return number.stringValue
            } else if let bool = value as? Bool {
              return bool ? "true" : "false"
            } else {
              return String(describing: value)
            }
          }

          // Use form encoding logic
          var components = URLComponents()
          components.queryItems = stringDict.map { URLQueryItem(name: $0.key, value: $0.value) }
          let escapedString = components.percentEncodedQuery?.replacingOccurrences(of: "%20", with: "+")
          $0.add(value: "application/x-www-form-urlencoded", forHeader: "Content-Type")
          $0.request.httpBody = escapedString?.data(using: .utf8)
        }
      } catch {
        ClerkLogger.logError(error, message: "Failed to form-encode object.")
      }
    }
  }

}
