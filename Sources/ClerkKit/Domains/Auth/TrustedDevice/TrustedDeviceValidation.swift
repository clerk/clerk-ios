//
//  TrustedDeviceValidation.swift
//  Clerk
//

import Foundation

package struct TrustedDeviceValidation: Codable, Equatable {
  var valid: Bool
}

extension TrustedDeviceValidation {
  struct Params: Encodable {
    var trustedDeviceId: String
  }
}
