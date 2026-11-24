//
//  ClerkQueryItemsRequestMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkQueryItemsRequestMiddleware: ClerkRequestMiddleware {
  func prepare(_ request: inout URLRequest) async throws {
    var queryItems = [URLQueryItem(name: "_is_native", value: "true")]
    if request.clerkClientSyncPolicy == .requestAndApply {
      queryItems.append(ClientSyncPolicy.includeClientQueryItem)
    }
    request.appendQueryItems(queryItems)
  }
}
