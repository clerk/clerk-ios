//
//  JSON+WebAuthn.swift
//

import Foundation

extension JSON {
  var webAuthnAssertionRelyingPartyIdentifier: String? {
    guard let identifier = self["rpId"]?.stringValue, !identifier.isEmpty else {
      return nil
    }
    return identifier
  }

  var webAuthnAssertionAllowedCredentialIDs: [Data] {
    guard let allowedCredentials = self["allowCredentials"]?.arrayValue else {
      return []
    }

    return allowedCredentials.compactMap { credential in
      guard
        let id = credential["id"]?.stringValue,
        !id.isEmpty
      else {
        return nil
      }

      return id.dataFromBase64URL()
    }
  }
}
