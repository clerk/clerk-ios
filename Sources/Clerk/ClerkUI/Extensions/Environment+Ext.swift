//
//  Environment+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

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
  
}
