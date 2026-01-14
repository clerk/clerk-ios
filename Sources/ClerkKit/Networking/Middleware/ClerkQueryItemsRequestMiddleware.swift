//
//  ClerkQueryItemsRequestMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkQueryItemsRequestMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    request.url?.append(queryItems: [.init(name: "_is_native", value: "true")])
  }
}
