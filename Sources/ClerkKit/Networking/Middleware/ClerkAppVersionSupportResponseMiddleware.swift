//
//  ClerkAppVersionSupportResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkAppVersionSupportResponseMiddleware: ClerkResponseMiddleware {
  static let statusHeader = "X-Clerk-App-Version-Status"
  static let supportedStatus = "supported"

  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    let requestSequence = request.clerkRequestSequence
    if response.statusCode == 403,
       let error = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data).errors.first,
       error.code == "unsupported_app_version"
    {
      try? await runtimeScope.withCurrentClerk { $0.applyUnsupportedAppVersion(meta: error.meta, requestSequence: requestSequence) }
    } else if response.value(forHTTPHeaderField: Self.statusHeader)?.lowercased() == Self.supportedStatus {
      try? await runtimeScope.withCurrentClerk { $0.applySupportedAppVersion(requestSequence: requestSequence) }
    }
  }
}
