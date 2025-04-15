//
//  Previews+Factory.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

import Factory
import Foundation

extension Container {

  func setupMocks() {
    clerk.register { @MainActor in
      var clerk = Clerk()
      clerk.environment = .init(
        userSettings: .init(
          attributes: [:],
          signUp: .init(
            customActionRequired: false,
            progressive: false,
            mode: "",
            legalConsentEnabled: true
          ),
          social: [
            "oauth_google": .init(
              enabled: true,
              required: false,
              authenticatable: true,
              strategy: "oauth_google",
              notSelectable: false,
              name: "Google",
              logoUrl: ""
            ),
            "oauth_apple": .init(
              enabled: true,
              required: false,
              authenticatable: true,
              strategy: "oauth_apple",
              notSelectable: false,
              name: "Apple",
              logoUrl: ""
            ),
            "oauth_slack": .init(
              enabled: true,
              required: false,
              authenticatable: true,
              strategy: "oauth_slack",
              notSelectable: false,
              name: "Slack",
              logoUrl: ""
            )
          ],
          actions: .init(
            deleteSelf: true,
            createOrganization: true
          ),
          passkeySettings: .init(
            allowAutofill: true,
            showSignInButton: true
          )
        ),
        displayConfig: .init(
          instanceEnvironmentType: .development,
          applicationName: "Acme Co",
          preferredSignInStrategy: .otp,
          branded: true,
          logoImageUrl: "",
          homeUrl: "",
          privacyPolicyUrl: "privacy",
          termsUrl: "terms"
        )
      )
      
      return clerk
    }
  }

}
