//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if !os(macOS)

import Foundation
import SwiftUI

public struct ClerkTheme {
    public var signIn = SignIn()
    
    public struct SignIn {
        
        public enum PresentationStyle {
            case sheet
            case modal
        }
        
        public var presentationStyle: PresentationStyle = .sheet
        public var modalBackground: AnyView = AnyView(Color.clear.background(.ultraThinMaterial))
    }
    
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

#endif
