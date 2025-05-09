//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

#if os(iOS)

  import Foundation

  extension Clerk.Environment {

    var authenticatableSocialProviders: [OAuthProvider] {
      guard let social = userSettings?.social else {
        return []
      }

      let authenticatables = social.filter { key, value in
        value.authenticatable && value.enabled
      }

      return authenticatables.map({
        OAuthProvider(strategy: $0.value.strategy)
      }).sorted()
    }

    var enabledFirstFactorAttributes: [String] {
      guard let userSettings else { return [] }

      return userSettings.attributes
        .filter { _, value in
          value.enabled && value.usedForFirstFactor
        }
        .map(\.key)
    }
    
    var mutliSessionModeIsEnabled: Bool {
      guard let authConfig else { return false }
      return authConfig.singleSessionMode == false
    }
    
    var billingIsEnabled: Bool {
      guard let commerceSettings else { return false }
      return commerceSettings.billing.enabled
    }

  }

#endif
