//
//  JSON+WebAuthn.swift
//

extension JSON {
  var webAuthnAssertionRelyingPartyIdentifier: String? {
    guard let identifier = self["rpId"]?.stringValue, !identifier.isEmpty else {
      return nil
    }
    return identifier
  }
}
