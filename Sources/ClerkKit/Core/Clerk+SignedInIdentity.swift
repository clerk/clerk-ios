//
//  Clerk+SignedInIdentity.swift
//  Clerk
//

import Foundation

package struct ClerkSignedInIdentity: Equatable {
  package let clientId: String?
  package let sessionId: String?

  package init(clientId: String?, sessionId: String?) {
    self.clientId = clientId
    self.sessionId = sessionId
  }
}

extension Clerk {
  @MainActor
  package func signedInIdentity(adoptingStoredDeviceToken: Bool) -> ClerkSignedInIdentity {
    if adoptingStoredDeviceToken {
      identityController.adoptStoredDeviceToken()
    }
    return ClerkSignedInIdentity(clientId: client?.id, sessionId: session?.id)
  }
}
