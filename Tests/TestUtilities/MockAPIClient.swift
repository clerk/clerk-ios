//
//  MockAPIClient.swift
//  Clerk
//
//  Created by Mike Pitre on 2/23/25.
//

import FactoryKit
import Foundation
import Mocker
import RequestBuilder

@testable import Clerk

let mockBaseUrl = URL(string: "https://clerk.mock.dev")!

extension Container: @retroactive AutoRegistering {

  public func autoRegister() {
    apiClient.context(.test) { _ in
      let configuration = URLSessionConfiguration.default
      configuration.protocolClasses = [MockingURLProtocol.self]
      let session = URLSession(configuration: configuration)
      return BaseSessionManager(base: mockBaseUrl, session: session)
        .set(encoder: JSONEncoder.clerkEncoder)
        .set(decoder: JSONDecoder.clerkDecoder)
        .interceptor(URLRequestInterceptorClerkHeaders())
        .interceptor(URLRequestInterceptorQueryItems())
        .interceptor(URLRequestInterceptorInvalidAuth())
        .interceptor(URLRequestInterceptorDeviceAssertion())
        .interceptor(URLRequestInterceptorDeviceTokenSaving())
        .interceptor(URLRequestInterceptorClientSync())
        .interceptor(URLRequestInterceptorEventEmitter())
        .interceptor(URLRequestInterceptorClerkErrorThrowing())
        .interceptor(URLRequestInterceptorMock())
    }
  }

}
