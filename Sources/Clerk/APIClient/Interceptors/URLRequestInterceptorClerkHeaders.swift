//
//  URLRequestInterceptorClerkHeaders.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation
import RequestBuilder

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

    if Clerk.shared.settings.debugMode, let client = try? Container.shared.clerkService().loadClientFromKeychain() {
      headers["x-clerk-client-id"] = client.id
    }
    
    return URLRequestBuilder(manager: self, builder: parent.request(forURL: url))
      .add(headers: headers)
  }
  
}
