//
//  View+HideKeyboard.swift
//  Clerk
//
//  Created by Mike Pitre on 4/28/25.
//

#if canImport(SwiftUI)

import Foundation
import SwiftUI

extension EnvironmentValues {
  @Entry var dismissKeyboard: () -> Void = {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

#endif
