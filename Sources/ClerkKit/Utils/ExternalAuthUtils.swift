//
//  ExternalAuthUtils.swift
//
//
//  Created by Mike Pitre on 7/2/24.
//

import AuthenticationServices
import Foundation

enum ExternalAuthUtils {
  static func nonceFromCallbackUrl(url: URL) -> String? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      return nil
    }

    guard
      let nonceQueryItem = components.queryItems?.first(where: { item in
        item.name == "rotating_token_nonce"
      })
    else {
      return nil
    }

    return nonceQueryItem.value
  }
}
