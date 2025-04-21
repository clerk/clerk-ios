//
//  SignIn+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/21/25.
//

import Foundation

extension SignIn {

  @MainActor
  var startingSignInFactor: Factor? {
    guard let supportedFirstFactors, !supportedFirstFactors.isEmpty else {
      return nil
    }
    
    let preferredSignInStrategy = Clerk.shared.environment.displayConfig?.preferredSignInStrategy

    if preferredSignInStrategy == .password {
      return factorWhenPasswordIsPreferred
    } else {
      return factorWhenOtpIsPreferred
    }
  }

  var factorWhenPasswordIsPreferred: Factor? {
    
    // email links are not supported on iOS
    let availableFirstFactors = supportedFirstFactors?.filter { factor in
      factor.strategy != "email_link"
    }
        
    if let passkeyFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == "passkey"
    }) {
      return passkeyFactor
    }
    
    if let passwordFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == "password"
    }) {
      return passwordFactor
    }
    
    let sortedFactors = availableFirstFactors?.sorted(using: Factor.passwordPrefComparator)
    
    return availableFirstFactors?.first { factor in
      factor.safeIdentifier == identifier
    } ?? sortedFactors?.first
  }
  
  var factorWhenOtpIsPreferred: Factor? {
    
    // email links are not supported on iOS
    let availableFirstFactors = supportedFirstFactors?.filter { factor in
      factor.strategy != "email_link"
    }
    
    if let passkeyFactor = availableFirstFactors?.first(where: { factor in
      factor.strategy == "passkey"
    }) {
      return passkeyFactor
    }
    
    let sortedFactors = availableFirstFactors?.sorted(using: Factor.otpPrefComparator)
    
    return sortedFactors?.first { factor in
      factor.safeIdentifier == identifier
    } ?? sortedFactors?.first
    
  }

}
