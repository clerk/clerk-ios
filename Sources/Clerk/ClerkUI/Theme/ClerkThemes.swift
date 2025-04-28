//
//  ClerkThemes.swift
//  Clerk
//
//  Created by Mike Pitre on 4/10/25.
//

#if canImport(SwiftUI)

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
      primary: Color(.clerkPrimary),
      danger: Color(.clerkDanger),
      textOnPrimaryBackground: Color(.clerkTextOnPrimaryBackground),
      neutral: Color(.clerkNeutral)
    ),
    design: .init(
      borderRadius: 8.0
    )
  )
}

extension EnvironmentValues {
  @Entry public var clerkTheme = ClerkTheme.default
}

#endif
