//
//  Router.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

import ClerkKit
import SwiftUI

/// Centralized navigation state for the authentication flow.
@MainActor
@Observable
final class Router {
  /// Navigation path for push-based navigation within the auth flow.
  var authPath = NavigationPath()

  /// Controls the presentation of the OTP verification sheet.
  var showOTPVerification = false
}

/// Type-safe navigation destinations for the authentication flow.
enum AuthDestination: Hashable {
  /// Navigate to the finish signing up view with the user's identifier information.
  case finishSigningUp(identifierValue: String, loginMode: LoginMode)
}
