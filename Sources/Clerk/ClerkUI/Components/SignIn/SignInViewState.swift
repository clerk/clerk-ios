//
//  SignInViewState.swift
//  Clerk
//
//  Created by Mike Pitre on 4/15/25.
//

import Foundation
import SwiftUI

@Observable
final class SignInViewState {
  enum FlowStep {
    case start
    case firstFactor
    
    @ViewBuilder
    var view: some View {
      switch self {
      case .start:
        SignInStartView()
      case .firstFactor:
        SignInFactorOneView()
      }
    }
  }
  
  var flowStep = FlowStep.start
  var identifier: String = ""
  var password: String = ""
}
