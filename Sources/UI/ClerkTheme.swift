//
//  ClerkTheme.swift
//
//
//  Created by Mike Pitre on 10/12/23.
//

#if canImport(UIKit)

import SwiftUI

public struct ClerkTheme {
    public var signUp: SignUp
    public var signIn: SignIn
    public var colors: Colors
    
    public struct Colors {
        public var primary: Color
    }
    
    public struct SignIn {
        
        public enum PresentationStyle {
            case sheet
            case fullScreenCover
        }
        
        public var presentationStyle: PresentationStyle
    }
    
    public struct SignUp {
        public enum PresentationStyle {
            case sheet
            case fullScreenCover
        }
        
        public var presentationStyle: PresentationStyle
    }
    
}

extension ClerkTheme {
    
    static let `default` = Self(
        signUp: .init(
            presentationStyle: .sheet
        ),
        signIn: .init(
            presentationStyle: .sheet
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
