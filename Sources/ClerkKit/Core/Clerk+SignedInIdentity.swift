//
//  Clerk+SignedInIdentity.swift
//  Clerk
//

import Foundation

package struct ClerkSignedInIdentity: Equatable {
  package let sessionId: String?
  package let deviceToken: String?

  package init(sessionId: String?, deviceToken: String?) {
    self.sessionId = sessionId
    self.deviceToken = deviceToken
  }
}

extension Clerk {
  @MainActor
  package func signedInIdentity() -> ClerkSignedInIdentity {
    identityController.adoptStoredDeviceToken()
    return ClerkSignedInIdentity(sessionId: session?.id, deviceToken: identityController.currentDeviceToken)
  }
}
