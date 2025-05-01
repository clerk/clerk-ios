//
//  View+DismissKeyboard.swift
//  Clerk
//
//  Created by Mike Pitre on 4/28/25.
//

#if os(iOS)

import Foundation
import SwiftUI

extension EnvironmentValues {
  @Entry var dismissKeyboard = {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

#endif
