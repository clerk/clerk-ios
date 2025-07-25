//
//  URLRequestInterceptorQueryItems.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorQueryItems: URLRequestInterceptor, @unchecked Sendable {
  
  var parent: URLSessionManager!

  func request(forURL url: URL?) -> URLRequestBuilder {
    URLRequestBuilder(manager: self, url: url)
      .add(queryItems: [.init(name: "_is_native", value: "true")])
  }
  
}

