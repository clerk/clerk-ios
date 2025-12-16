//
//  KeyboardDismissal.swift
//  AirbnbClone
//
//  Created by Mike Pitre on 12/15/25.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

extension UIApplication {
  func endEditing() {
    sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}

extension View {
  func dismissKeyboard() {
    UIApplication.shared.endEditing()
  }
}
#endif
