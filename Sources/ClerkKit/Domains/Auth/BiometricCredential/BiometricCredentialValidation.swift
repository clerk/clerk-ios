//
//  BiometricCredentialValidation.swift
//  Clerk
//

import Foundation

package struct BiometricCredentialValidation: Codable, Equatable {
  var valid: Bool
}

extension BiometricCredentialValidation {
  struct Params: Encodable {
    var biometricCredentialId: String

    private enum CodingKeys: String, CodingKey {
      case biometricCredentialId = "trustedDeviceId"
    }
  }
}
