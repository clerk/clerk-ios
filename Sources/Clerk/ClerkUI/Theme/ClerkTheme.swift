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
  
  public init(
    colors: ClerkTheme.Colors = .default
  ) {
    self.colors = colors
  }
  
  public static var `default`: ClerkTheme {
    .init(
      colors: .default
    )
  }
}

extension EnvironmentValues {
  @Entry public var clerkTheme = ClerkTheme.default
}
