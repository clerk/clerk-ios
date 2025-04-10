//
//  ClerkColors.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

import SwiftUI

extension ClerkTheme {
  public struct Colors {

    public var primary: Color
    public var textPrimary: Color
    public var textSecondary: Color

    public init(
      primary: Color = Self.default.primary,
      textPrimary: Color = Self.default.textPrimary,
      textSecondary: Color = Self.default.textSecondary
    ) {
      self.primary = primary
      self.textPrimary = textPrimary
      self.textSecondary = textSecondary
    }
  }
}

extension ClerkTheme.Colors {

  public static var `default`: Self {
    .init(
      primary: Color(.defaultPrimary),
      textPrimary: Color(.defaultTextPrimary),
      textSecondary: Color(.defaultTextSecondary)
    )
  }

}
