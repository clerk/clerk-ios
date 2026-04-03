//
//  ClerkURLRoute.swift
//  Clerk
//

import Foundation

enum ClerkURLRoute: Hashable {
  case magicLink(flowId: String, approvalToken: String)

  @MainActor
  init?(url: URL) throws {
    if MagicLinkCallback.canHandle(url, redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl) {
      let callback = try MagicLinkCallback(url: url)
      self = .magicLink(
        flowId: callback.flowId,
        approvalToken: callback.approvalToken
      )
      return
    }

    return nil
  }
}
