//
//  ClerkDeviceTokenResponseMiddleware.swift
//  Clerk
//

import Foundation

enum ClerkDeviceTokenResponseUpdate: Equatable {
  case absent
  case set(String)
  case clear

  init(authorizationHeader: String?) {
    guard let authorizationHeader else {
      self = .absent
      return
    }

    let normalized = authorizationHeader.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty || normalized.caseInsensitiveCompare("Bearer") == .orderedSame {
      self = .clear
    } else {
      self = .set(normalized)
    }
  }
}
