//
//  Theme.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

import Foundation
import SwiftUI

@Observable
public class ClerkTheme {
  public var colors: Colors
  public var fonts: Fonts
  
  public init(
    colors: Colors = .default,
    fonts: Fonts = .default
  ) {
    self.colors = colors
    self.fonts = fonts
  }
  
  public static var `default`: ClerkTheme {
    .init(
      colors: .default,
      fonts: .default
    )
  }
}

extension EnvironmentValues {
  @Entry public var clerkTheme = ClerkTheme.default
}
