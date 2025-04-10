//
//  ClerkThemes.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

import Foundation
import SwiftUI

extension ClerkTheme {
  
  public static let `default`: ClerkTheme = .init(
    colors: .default,
    fonts: .default,
    design: .default
  )

  public static let clerk: ClerkTheme = .init(
    colors: .init(
      primary: Color(hex: "#5760FAFF"),
      danger: Color(hex: "#DC2626FF"),
      neutral: Color(hex: "#2B2B34FF")
    ),
    design: .init(
      borderRadius: 8.0
    )
  )
}
