//
//  ClerkQueryItemsRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkQueryItemsRequestMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    request.appendQueryItems([.init(name: "_is_native", value: "true")])
  }
}
