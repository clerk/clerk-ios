//
//  ExternalAccountService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Factory
import Foundation

struct ExternalAccountService {
  var reauthorize: @MainActor (_ id: String, _ verification: Verification?, _ prefersEphemeralWebBrowserSession: Bool) async throws -> ExternalAccount
  var destroy: @MainActor (_ id: String) async throws -> DeletedObject
}

extension ExternalAccountService {
  
  static var liveValue: Self {
    .init(
      reauthorize: { id, verification, prefersEphemeralWebBrowserSession in
        guard
            let redirectUrl = verification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        let authSession = WebAuthentication(
            url: url,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
        )
        
        _ = try await authSession.start()
        
        try await Client.get()
        guard let externalAccount = Clerk.shared.user?.externalAccounts.first(where: { $0.id == id }) else {
            throw ClerkClientError(message: "Something went wrong. Please try again.")
        }
        return externalAccount
      },
      destroy: { id in
        let request = ClerkFAPI.v1.me.externalAccounts.id(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        return try await Clerk.shared.apiClient.send(request).value.response
      }
    )
  }
  
}

extension Container {
  
  var externalAccountService: Factory<ExternalAccountService> {
    self { .liveValue }
  }
  
}
