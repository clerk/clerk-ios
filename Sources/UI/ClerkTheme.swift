//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import SwiftUI

public struct ClerkTheme {
    public var signIn: SignIn
    public var colors: Colors
    
    public struct Colors {
        public var primary: Color
    }
    
    public struct SignIn {
        
        public enum PresentationStyle {
            case sheet
            case fullScreenCover
            case modal
        }
        
        public var presentationStyle: PresentationStyle
        public var modalBackground: AnyView
    }
    
}

extension ClerkTheme {
    
    static let `default` = Self(
        signIn: .init(
            presentationStyle: .sheet,
            modalBackground: AnyView(Color.clear.background(.regularMaterial))
        ),
        colors: .init(
            primary: Color(.clerkPurple)
        )
    )
    
}

struct ClerkThemeKey: EnvironmentKey {
    static let defaultValue: ClerkTheme = .default
}

extension EnvironmentValues {
  public var clerkTheme: ClerkTheme {
    get { self[ClerkThemeKey.self] }
    set { self[ClerkThemeKey.self] = newValue }
  }
}

#endif
