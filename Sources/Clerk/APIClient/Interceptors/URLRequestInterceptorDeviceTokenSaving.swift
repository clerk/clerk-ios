//
//  URLRequestInterceptorDeviceTokenSaving.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import FactoryKit
import Foundation
import RequestBuilder

final class URLRequestInterceptorDeviceTokenSaving: URLRequestInterceptor, @unchecked Sendable {
  
  var parent: URLSessionManager!
  
  func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
    let (data, response) = try await parent.data(for: request)
    
    // Set the device token from the response headers whenever received
    if let response, let deviceToken = response.value(forHTTPHeaderField: "Authorization") {
      try? Container.shared.keychain().set(deviceToken, forKey: "clerkDeviceToken")
    }
    
    return (data, response)
  }
}
