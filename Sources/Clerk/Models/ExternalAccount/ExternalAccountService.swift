//
//  ExternalAccountService.swift
//  Clerk
//
//  Created by Mike Pitre on 2/26/25.
//

import Factory
import Foundation

struct ExternalAccountService {
  var reauthorize: (_ externalAccount: ExternalAccount, _ prefersEphemeralWebBrowserSession: Bool) async throws -> ExternalAccount
  var destroy: (_ externalAccount: ExternalAccount) async throws -> DeletedObject
}

extension ExternalAccountService {
  
  static var liveValue: Self {
    .init(
      reauthorize: { externalAccount, prefersEphemeralWebBrowserSession in
        guard
          let redirectUrl = externalAccount.verification?.externalVerificationRedirectUrl,
            let url = URL(string: redirectUrl)
        else {
            throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
        }
        
        let authSession = await WebAuthentication(url: url, prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession)
        
        _ = try await authSession.start()
        
        try await Client.get()
        guard let externalAccount = await Clerk.shared.user?.externalAccounts.first(where: { $0.id == externalAccount.id }) else {
            throw ClerkClientError(message: "Something went wrong. Please try again.")
        }
        return externalAccount
      },
      destroy: { externalAccount in
        let request = ClerkFAPI.v1.me.externalAccounts.id(externalAccount.id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: await Clerk.shared.session?.id)]
        )
        return try await Container.shared.apiClient().send(request).value.response
      }
    )
  }
  
}

extension Container {
  
  var externalAccountService: Factory<ExternalAccountService> {
    self { .liveValue }
  }
  
}
