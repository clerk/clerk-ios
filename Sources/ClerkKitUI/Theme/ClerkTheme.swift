//
//  ClerkTheme.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import Foundation
import SwiftUI

@Observable
public class ClerkTheme {
    public var colors: Colors
    public var fonts: Fonts
    public var design: Design

    public init(
        colors: Colors = .default,
        fonts: Fonts = .default,
        design: Design = .default
    ) {
        self.colors = colors
        self.fonts = fonts
        self.design = design
    }
}

#endif
