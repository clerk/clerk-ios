//
//  URLRequestInterceptorClerkHeaders.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation
import RequestBuilder

@MainActor
final class URLRequestInterceptorClerkHeaders: URLRequestInterceptor, @unchecked Sendable {
  
  var parent: URLSessionManager!
  
  func request(forURL url: URL?) -> URLRequestBuilder {
    var headers = [
      "clerk-api-version": "2024-10-01",
      "x-ios-sdk-version": Clerk.version,
      "x-mobile": "1",
      "x-native-device-id": deviceID
    ]
    
    // Set the device token on every request
    if let deviceToken = try? Container.shared.keychain().string(forKey: "clerkDeviceToken") {
      headers["Authorization"] = deviceToken
    }

    if Clerk.shared.settings.debugMode, let client = Clerk.shared.client {
      headers["x-clerk-client-id"] = client.id
    }
    
    return URLRequestBuilder(manager: self, builder: parent.request(forURL: url))
      .add(headers: headers)
  }
  
  private func loadClientFromKeychain() throws -> Client? {
    guard let clientData = try? Container.shared.keychain().data(forKey: "cachedClient") else {
      return nil
    }
    let decoder = JSONDecoder.clerkDecoder
    return try decoder.decode(Client.self, from: clientData)
  }
  
}
