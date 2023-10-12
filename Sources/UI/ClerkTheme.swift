//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

import Foundation
import SwiftUI

public struct ClerkTheme {
    public var signInPresentationStyle: SignInViewModifier.PresentationStyle = .sheet
}

struct ClerkThemeKey: EnvironmentKey {
    static let defaultValue: ClerkTheme = .init()
}

extension EnvironmentValues {
  public var clerkTheme: ClerkTheme {
    get { self[ClerkThemeKey.self] }
    set { self[ClerkThemeKey.self] = newValue }
  }
}
